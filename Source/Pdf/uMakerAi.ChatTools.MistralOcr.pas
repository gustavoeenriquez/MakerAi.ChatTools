unit uMakerAi.ChatTools.MistralOcr;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiMistralOcrTool
// Implementacion de IAiPdfTool usando la API OCR dedicada de Mistral AI.
// https://docs.mistral.ai/capabilities/document/
//
// PATRON DE REQUEST:
//   POST https://api.mistral.ai/v1/ocr
//   El PDF se envia como data URL base64: "data:application/pdf;base64,{data}"
//   en el campo document.document_url.
//
// DIFERENCIA CRITICA vs /v1/chat/completions:
//   'mistral-ocr-latest' usa un endpoint DEDICADO /v1/ocr — NO es el de chat.
//   Mismo patron que ya existe en MakerAI internamente, pero aqui standalone.
//
// SINCRONO: respuesta inmediata, sin polling.
// Una sola llamada HTTP. Igual que Stability AI vs fal.ai en los image tools.
//
// ESTRUCTURA DE RESPUESTA:
//   { "pages": [{"index": 0, "markdown": "..."}, ...] }
//   Se concatenan todos los pages[*].markdown para obtener el texto completo.
//
// Env var requerida: MISTRAL_API_KEY
// Obtener en: https://console.mistral.ai/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiMistralOcrTool = class(TAiPdfToolBase)
  private
    FApiKey            : String;
    FModel             : String;
    FIncludeImageBase64: Boolean;
    FTargetPages       : String;

    function ResolveApiKey: String;
    function BuildRequestJSON(const ABase64Pdf: String): TJSONObject;
    function ExtractText(AResponse: TJSONObject): String;
  protected
    procedure ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
                                 ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Mistral. Soporta '@ENV_VAR' (default '@MISTRAL_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo OCR (solo 'mistral-ocr-latest' disponible actualmente)
    property Model: String read FModel write FModel;
    // Si True, incluye las imagenes del documento como base64 en la respuesta
    property IncludeImageBase64: Boolean
             read FIncludeImageBase64 write FIncludeImageBase64 default False;
    // Páginas especificas a procesar como lista JSON: '[0,1,2]' (vacío = todas)
    property TargetPages: String read FTargetPages write FTargetPages;
  end;

const
  MISTRAL_OCR_URL = 'https://api.mistral.ai/v1/ocr';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiMistralOcrTool]);
end;

constructor TAiMistralOcrTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey             := '@MISTRAL_API_KEY';
  FModel              := 'mistral-ocr-latest';
  FIncludeImageBase64 := False;
  FTargetPages        := '';
end;

function TAiMistralOcrTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para la API OCR de Mistral.
// El PDF se envuelve en un data URL: "data:application/pdf;base64,{base64}"
// en lugar de enviarse como multipart (diferencia vs Unstructured/LlamaParse).
// ---------------------------------------------------------------------------
function TAiMistralOcrTool.BuildRequestJSON(const ABase64Pdf: String): TJSONObject;
var
  JDocument: TJSONObject;
  JPages   : TJSONArray;
  LDataUrl : String;
  I, PageNum: Integer;
  LPageStr : String;
begin
  // Formato data URL requerido por Mistral OCR
  LDataUrl := 'data:application/pdf;base64,' + ABase64Pdf;

  JDocument := TJSONObject.Create;
  JDocument.AddPair('type',         'base64');
  JDocument.AddPair('document_url', LDataUrl);

  Result := TJSONObject.Create;
  Result.AddPair('model',    FModel);
  Result.AddPair('document', JDocument);

  if FIncludeImageBase64 then
    Result.AddPair('include_image_base64', TJSONBool.Create(True));

  // Parsear páginas especificas si se configuraron: '0,1,2' -> [0,1,2]
  if FTargetPages <> '' then
  begin
    JPages := TJSONArray.Create;
    LPageStr := FTargetPages;
    // Eliminar corchetes si los tiene
    LPageStr := LPageStr.Replace('[','').Replace(']','');
    for LPageStr in LPageStr.Split([',']) do
    begin
      LPageStr := Trim(LPageStr);
      if TryStrToInt(LPageStr, PageNum) then
        JPages.Add(PageNum);
    end;
    if JPages.Count > 0 then
      Result.AddPair('pages', JPages)
    else
      JPages.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Extrae el texto de la respuesta: concatena pages[*].markdown.
// Cada pagina tiene su propio bloque de markdown — se unen con separador.
// ---------------------------------------------------------------------------
function TAiMistralOcrTool.ExtractText(AResponse: TJSONObject): String;
var
  SB     : TStringBuilder;
  JPages : TJSONArray;
  JPage  : TJSONObject;
  LMd    : String;
  I      : Integer;
begin
  SB := TStringBuilder.Create;
  try
    if AResponse.TryGetValue<TJSONArray>('pages', JPages) then
    begin
      for I := 0 to JPages.Count - 1 do
      begin
        JPage := TJSONObject(JPages.Items[I]);
        if JPage.TryGetValue<String>('markdown', LMd) and (LMd <> '') then
        begin
          if SB.Length > 0 then
            SB.AppendLine;
          SB.Append(LMd);
        end;
      end;
    end;
    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Ejecuta el OCR: una sola llamada POST sincrona — sin polling.
// ---------------------------------------------------------------------------
procedure TAiMistralOcrTool.ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResult  : TJSONObject;
  LBytes   : TBytes;
  LBase64  : String;
  LText    : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Mistral OCR: archivo PDF no disponible', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Mistral OCR: procesando PDF...');

  // Codificar el PDF en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(LBase64);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResponse := LClient.Post(MISTRAL_OCR_URL, LBody, nil, [
        TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
        TNetHeader.Create('Content-Type',  'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Mistral OCR error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Mistral OCR: respuesta JSON inválida');
      try
        LText := ExtractText(LResult);
      finally
        LResult.Free;
      end;

      if LText.IsEmpty then
        raise Exception.Create('Mistral OCR: resultado vacío');

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);

    except
      on E: Exception do
      begin
        ReportError(E.Message, E);
        ResMsg.Prompt := '';
      end;
    end;
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

end.
