unit uMakerAi.ChatTools.Reducto;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiReductoPdfTool
// Implementacion de IAiPdfTool usando Reducto AI.
// https://docs.reducto.ai/api-reference/parse
//
// Reducto es un parser de PDF de alta precisión orientado a documentos
// financieros, legales y tecnicos. Excelente extracción de tablas y formulas.
//
// PATRON DE REQUEST:
//   El PDF se envia como base64 en el body JSON:
//   {"document": {"type": "application/pdf", "content": "BASE64..."}, ...}
//
// PATRON DE RESPUESTA:
//   Generalmente síncrono (respuesta directa con el texto).
//   Si la respuesta incluye 'job_id', el parseo es asíncrono → polling.
//
// AUTENTICACION: 'Authorization: Bearer {key}'
//
// Env var requerida: REDUCTO_API_KEY
// Obtener en: https://reducto.ai

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiReductoPdfTool = class(TAiPdfToolBase)
  private
    FApiKey             : String;
    FParseMode          : String;
    FOutputFormat       : String;
    FFigureMode         : String;
    FExtractTables      : Boolean;
    FIncludePageNumbers : Boolean;

    function ResolveApiKey: String;
    function BuildRequestJSON(const ABase64: String): TJSONObject;
    function PollJob(const AJobId: String): String;
    function ExtractText(AResponse: TJSONObject): String;
  protected
    procedure ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
                                 ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Reducto. Soporta '@ENV_VAR' (default '@REDUCTO_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modo de parseo: 'ocr' (rápido), 'accurate' (preciso) (default 'ocr')
    property ParseMode: String read FParseMode write FParseMode;
    // Formato de salida: 'markdown', 'html', 'chunks' (default 'markdown')
    property OutputFormat: String read FOutputFormat write FOutputFormat;
    // Tratamiento de figuras: 'ignore', 'description' (default 'ignore')
    property FigureMode: String read FFigureMode write FFigureMode;
    // Si True, extrae tablas en formato estructurado (default True)
    property ExtractTables: Boolean
             read FExtractTables write FExtractTables default True;
    // Si True, incluye números de pagina en el output (default False)
    property IncludePageNumbers: Boolean
             read FIncludePageNumbers write FIncludePageNumbers default False;
  end;

const
  REDUCTO_PARSE_URL  = 'https://v1.api.reducto.ai/parse';
  REDUCTO_STATUS_URL = 'https://v1.api.reducto.ai/status/';
  REDUCTO_POLL_MS    = 3000;
  REDUCTO_MAX_POLLS  = 40;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiReductoPdfTool]);
end;

constructor TAiReductoPdfTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey             := '@REDUCTO_API_KEY';
  FParseMode          := 'ocr';
  FOutputFormat       := 'markdown';
  FFigureMode         := 'ignore';
  FExtractTables      := True;
  FIncludePageNumbers := False;
end;

function TAiReductoPdfTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON con el PDF en base64.
// Reducto no usa multipart — el PDF va codificado en el body JSON.
// ---------------------------------------------------------------------------
function TAiReductoPdfTool.BuildRequestJSON(const ABase64: String): TJSONObject;
var
  JDocument: TJSONObject;
  JOptions : TJSONObject;
begin
  JDocument := TJSONObject.Create;
  JDocument.AddPair('type',    'application/pdf');
  JDocument.AddPair('content', ABase64);

  JOptions := TJSONObject.Create;
  JOptions.AddPair('parse_mode',           FParseMode);
  JOptions.AddPair('output_format',        FOutputFormat);
  JOptions.AddPair('figure_mode',          FFigureMode);
  JOptions.AddPair('extract_tables',       TJSONBool.Create(FExtractTables));
  JOptions.AddPair('include_page_numbers', TJSONBool.Create(FIncludePageNumbers));

  Result := TJSONObject.Create;
  Result.AddPair('document', JDocument);
  Result.AddPair('options',  JOptions);
end;

// ---------------------------------------------------------------------------
// Polling para modo asíncrono (documentos grandes).
// Retorna el texto cuando el job esta completo.
// ---------------------------------------------------------------------------
function TAiReductoPdfTool.PollJob(const AJobId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  LHeaders : TNetHeaders;
begin
  Result    := '';
  LAttempts := 0;
  LHeaders  := [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)];
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(REDUCTO_POLL_MS);

      LResponse := LClient.Get(REDUCTO_STATUS_URL + AJobId, nil, LHeaders);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        if SameText(LStatus, 'completed') or SameText(LStatus, 'success') then
          Result := ExtractText(LResult)
        else if SameText(LStatus, 'failed') or SameText(LStatus, 'error') then
          raise Exception.Create('Reducto: error al procesar el documento');
      finally
        LResult.Free;
      end;
    until (Result <> '') or (LAttempts >= REDUCTO_MAX_POLLS);
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Extrae el texto del resultado de Reducto.
// El campo varia segun el OutputFormat: 'markdown', 'html', o 'chunks'.
// ---------------------------------------------------------------------------
function TAiReductoPdfTool.ExtractText(AResponse: TJSONObject): String;
var
  LResult: TJSONValue;
begin
  Result := '';
  if not Assigned(AResponse) then Exit;

  // Intentar los campos conocidos en orden de preferencia
  if AResponse.TryGetValue<String>(FOutputFormat, Result) then Exit;
  if AResponse.TryGetValue<String>('markdown', Result) then Exit;
  if AResponse.TryGetValue<String>('content', Result) then Exit;
  if AResponse.TryGetValue<String>('text', Result) then Exit;

  // Si 'result' es un objeto anidado
  if AResponse.TryGetValue<TJSONValue>('result', LResult) then
  begin
    if LResult is TJSONObject then
      Result := TJSONObject(LResult).GetValue<String>(FOutputFormat, '')
    else
      Result := LResult.Value;
  end;
end;

procedure TAiReductoPdfTool.ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LHeaders : TNetHeaders;
  LResult  : TJSONObject;
  LBytes   : TBytes;
  LBase64  : String;
  LText    : String;
  LJobId   : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Reducto: archivo PDF no disponible', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Reducto [' + FParseMode + ']: analizando PDF...');

  // Codificar el PDF en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(LBase64);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  'application/json')
    ];

    try
      LResponse := LClient.Post(REDUCTO_PARSE_URL, LBody, nil, LHeaders);

      if not (LResponse.StatusCode in [200, 202]) then
        raise Exception.CreateFmt('Reducto error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Reducto: respuesta JSON invalida');
      try
        // Verificar si la respuesta es sincrona o asincrona
        if LResult.TryGetValue<String>('job_id', LJobId) and (LJobId <> '') then
        begin
          // Modo asíncrono: hacer polling
          LResult.Free;
          LResult := nil;
          ReportState(acsReasoning, 'Reducto: procesando (modo asíncrono)...');
          LText := PollJob(LJobId);
        end
        else
        begin
          // Modo síncrono: el resultado viene directo
          LText := ExtractText(LResult);
        end;
      finally
        LResult.Free;
      end;

      if LText.IsEmpty then
        raise Exception.Create('Reducto: resultado vacío');

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
