unit uMakerAi.ChatTools.Unstructured;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiUnstructuredPdfTool
// Implementacion de IAiPdfTool usando Unstructured.io.
// https://docs.unstructured.io/api-reference/api-services/api
//
// Unstructured.io es un parser multiformato open-source (PDF, Word, Excel,
// HTML, Markdown, etc.). La API cloud soporta 25+ formatos de documento.
//
// PATRON DE REQUEST: multipart/form-data
//   Campo 'files': el archivo PDF
//   Campos adicionales: parametros de configuración
//
// DIFERENCIA DE AUTENTICACION:
//   Header personalizado: 'unstructured-api-key: {key}'
//   NO usa 'Authorization' ni 'Bearer'
//
// FORMATO DE RESPUESTA:
//   Array JSON de elementos: [{"type": "Title", "text": "..."}, ...]
//   Los tipos de elemento incluyen: Title, NarrativeText, Table, Image, etc.
//
// Env var requerida: UNSTRUCTURED_API_KEY
// Obtener en: https://unstructured.io/api-key-hosted

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiUnstructuredPdfTool = class(TAiPdfToolBase)
  private
    FApiKey          : String;
    FStrategy        : String;
    FChunkingStrategy: String;
    FMaxCharacters   : Integer;
    FLanguages       : String;
    FCoordinates     : Boolean;

    function ResolveApiKey: String;
    function FormatElements(AElements: TJSONArray): String;
  protected
    procedure ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
                                 ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Unstructured. Soporta '@ENV_VAR' (default '@UNSTRUCTURED_API_KEY')
    // Header personalizado: 'unstructured-api-key: {key}' (NO es Authorization)
    property ApiKey: String read FApiKey write FApiKey;
    // Estrategia de extracción: 'auto', 'fast', 'hi_res', 'ocr_only'
    // 'hi_res' es mas preciso pero mas lento (default 'auto')
    property Strategy: String read FStrategy write FStrategy;
    // Estrategia de chunking: '' (sin chunking), 'basic', 'by_title', 'by_page'
    // (default '' = sin chunking)
    property ChunkingStrategy: String
             read FChunkingStrategy write FChunkingStrategy;
    // Caracteres maximos por chunk (solo si ChunkingStrategy != '') (default 500)
    property MaxCharacters: Integer
             read FMaxCharacters write FMaxCharacters default 500;
    // Idiomas del documento: 'eng', 'spa', etc. Vacío = auto (default '')
    property Languages: String read FLanguages write FLanguages;
    // Si True, incluye coordenadas de cada elemento en el resultado (default False)
    property Coordinates: Boolean
             read FCoordinates write FCoordinates default False;
  end;

const
  UNSTRUCTURED_API_URL = 'https://api.unstructured.io/general/v0/general';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiUnstructuredPdfTool]);
end;

constructor TAiUnstructuredPdfTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey           := '@UNSTRUCTURED_API_KEY';
  FStrategy         := 'auto';
  FChunkingStrategy := '';
  FMaxCharacters    := 500;
  FLanguages        := '';
  FCoordinates      := False;
end;

function TAiUnstructuredPdfTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Convierte el array de elementos de Unstructured a texto plano.
// Cada elemento tiene 'type' y 'text'. Se concatenan preservando estructura.
// Tipos principales: Title, NarrativeText, ListItem, Table, Header, Footer
// ---------------------------------------------------------------------------
function TAiUnstructuredPdfTool.FormatElements(AElements: TJSONArray): String;
var
  SB     : TStringBuilder;
  JItem  : TJSONValue;
  JObj   : TJSONObject;
  LType  : String;
  LText  : String;
  I      : Integer;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to AElements.Count - 1 do
    begin
      JItem := AElements.Items[I];
      if not (JItem is TJSONObject) then Continue;
      JObj := TJSONObject(JItem);

      LType := JObj.GetValue<String>('type', '');
      LText := JObj.GetValue<String>('text', '');
      if LText.IsEmpty then Continue;

      // Formatear segun el tipo de elemento
      if SameText(LType, 'Title') then
        SB.AppendLine('# ' + LText)
      else if SameText(LType, 'Header') then
        SB.AppendLine('## ' + LText)
      else if SameText(LType, 'ListItem') then
        SB.AppendLine('- ' + LText)
      else
        SB.AppendLine(LText);

      SB.AppendLine;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

procedure TAiUnstructuredPdfTool.ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LForm    : TMultipartFormData;
  LCopy    : TMemoryStream;
  LHeaders : TNetHeaders;
  JElements: TJSONArray;
  LText    : String;
  LFileName: String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Unstructured: archivo PDF no disponible', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Unstructured [' + FStrategy + ']: analizando PDF...');

  LClient := THTTPClient.Create;
  LForm   := TMultipartFormData.Create;
  LCopy   := TMemoryStream.Create;
  try
    aMediaFile.Stream.Position := 0;
    LCopy.CopyFrom(aMediaFile.Stream, aMediaFile.Stream.Size);
    LCopy.Position := 0;

    LFileName := ExtractFileName(aMediaFile.FileName);
    if LFileName = '' then LFileName := 'document.pdf';

    // Campo 'files': el archivo PDF
    LForm.AddStream('files', LCopy, LFileName, 'application/pdf');
    // Parametros de configuración como form fields
    LForm.AddField('strategy',    FStrategy);
    LForm.AddField('coordinates', BoolToStr(FCoordinates, True).ToLower);

    if FChunkingStrategy <> '' then
    begin
      LForm.AddField('chunking_strategy', FChunkingStrategy);
      LForm.AddField('max_characters',    IntToStr(FMaxCharacters));
    end;
    if FLanguages <> '' then
      LForm.AddField('languages', FLanguages);

    // DIFERENCIA CLAVE: header 'unstructured-api-key' (no Authorization)
    LHeaders := [TNetHeader.Create('unstructured-api-key', ResolveApiKey)];

    try
      LResponse := LClient.Post(UNSTRUCTURED_API_URL, LForm, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Unstructured error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      // La respuesta es un array JSON de elementos
      JElements := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONArray;
      if not Assigned(JElements) then
        raise Exception.Create('Unstructured: respuesta JSON invalida');
      try
        LText := FormatElements(JElements);
      finally
        JElements.Free;
      end;

      if LText.IsEmpty then
        raise Exception.Create('Unstructured: resultado vacío');

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
    LCopy.Free;
    LForm.Free;
    LClient.Free;
  end;
end;

end.
