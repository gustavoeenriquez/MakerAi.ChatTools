unit uMakerAi.ChatTools.LlamaParse;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiLlamaParseToolPdf
// Implementacion de IAiPdfTool usando LlamaParse (LlamaIndex Cloud).
// https://docs.cloud.llamaindex.ai/llamaparse/getting_started
//
// LlamaParse es el parser de PDF mas preciso para LLMs. Maneja tablas complejas,
// columnas multiples, formulas matematicas y graficas mejor que OCR tradicional.
// La salida en Markdown preserva la estructura del documento.
//
// PATRON DE EJECUCION (asíncrono con polling):
//   Paso 1: POST multipart /upload -> job_id
//   Paso 2: GET polling /job/{id} hasta status='SUCCESS'
//   Paso 3: GET /job/{id}/result/{tipo} -> texto del documento
//
// Env var requerida: LLAMA_CLOUD_API_KEY
// Obtener en: https://cloud.llamaindex.ai/api-key

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiLlamaParseToolPdf = class(TAiPdfToolBase)
  private
    FApiKey             : String;
    FResultType         : String;
    FLanguage           : String;
    FSkipDiagonalText   : Boolean;
    FDoNotUnrollColumns : Boolean;
    FTargetPages        : String;
    FPremiumMode        : Boolean;

    function ResolveApiKey: String;
    function UploadPdf(aMediaFile: TAiMediaFile): String;
    function PollJob(const AJobId: String): Boolean;
    function FetchResult(const AJobId: String): String;
  protected
    procedure ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
                                 ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de LlamaIndex Cloud. Soporta '@ENV_VAR' (default '@LLAMA_CLOUD_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Formato de salida: 'markdown', 'text', 'json' (default 'markdown')
    // 'markdown' preserva tablas, encabezados y estructura del documento
    property ResultType: String read FResultType write FResultType;
    // Idioma del documento: 'es', 'en', etc. (default '' = auto-detección)
    property Language: String read FLanguage write FLanguage;
    // Si True, omite texto en diagonal (watermarks, etc.) (default False)
    property SkipDiagonalText: Boolean
             read FSkipDiagonalText write FSkipDiagonalText default False;
    // Si True, no fusiona columnas (preserva layout multi-columna) (default False)
    property DoNotUnrollColumns: Boolean
             read FDoNotUnrollColumns write FDoNotUnrollColumns default False;
    // Paginas a procesar: '0,1,2' o '0-5' (vacío = todas las paginas)
    property TargetPages: String read FTargetPages write FTargetPages;
    // Si True, usa modelos de mayor precisión (mayor costo) (default False)
    property PremiumMode: Boolean
             read FPremiumMode write FPremiumMode default False;
  end;

const
  LLAMAPARSE_BASE_URL = 'https://api.cloud.llamaindex.ai/api/v1/parsing/';
  LLAMAPARSE_POLL_MS  = 3000;
  LLAMAPARSE_MAX_POLLS= 60;  // 3 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiLlamaParseToolPdf]);
end;

constructor TAiLlamaParseToolPdf.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey             := '@LLAMA_CLOUD_API_KEY';
  FResultType         := 'markdown';
  FLanguage           := '';
  FSkipDiagonalText   := False;
  FDoNotUnrollColumns := False;
  FTargetPages        := '';
  FPremiumMode        := False;
end;

function TAiLlamaParseToolPdf.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Paso 1: Sube el PDF a LlamaParse con los parametros de parseo.
// Retorna el job_id para el polling.
// ---------------------------------------------------------------------------
function TAiLlamaParseToolPdf.UploadPdf(aMediaFile: TAiMediaFile): String;
var
  LClient  : THTTPClient;
  LForm    : TMultipartFormData;
  LCopy    : TMemoryStream;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
  LFileName: String;
begin
  Result  := '';
  LClient := THTTPClient.Create;
  LForm   := TMultipartFormData.Create;
  LCopy   := TMemoryStream.Create;
  try
    aMediaFile.Stream.Position := 0;
    LCopy.CopyFrom(aMediaFile.Stream, aMediaFile.Stream.Size);
    LCopy.Position := 0;

    LFileName := ExtractFileName(aMediaFile.FileName);
    if LFileName = '' then LFileName := 'document.pdf';

    // Archivo PDF
    LForm.AddStream('file', LCopy, LFileName, 'application/pdf');
    // Parametros de parseo como campos adicionales
    LForm.AddField('result_type', FResultType);
    if FLanguage <> '' then       LForm.AddField('language', FLanguage);
    if FSkipDiagonalText then     LForm.AddField('skip_diagonal_text', 'true');
    if FDoNotUnrollColumns then   LForm.AddField('do_not_unroll_columns', 'true');
    if FTargetPages <> '' then    LForm.AddField('target_pages', FTargetPages);
    if FPremiumMode then          LForm.AddField('premium_mode', 'true');

    LHeaders := [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)];

    LResponse := LClient.Post(LLAMAPARSE_BASE_URL + 'upload', LForm, nil, LHeaders);

    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('LlamaParse upload error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      Result := LResult.GetValue<String>('id', '');
    finally
      LResult.Free;
    end;
  finally
    LCopy.Free;
    LForm.Free;
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 2: Polling hasta status='SUCCESS'.
// ---------------------------------------------------------------------------
function TAiLlamaParseToolPdf.PollJob(const AJobId: String): Boolean;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  LHeaders : TNetHeaders;
begin
  Result    := False;
  LAttempts := 0;
  LHeaders  := [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)];
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(LLAMAPARSE_POLL_MS);

      LResponse := LClient.Get(
        LLAMAPARSE_BASE_URL + 'job/' + AJobId, nil, LHeaders);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        Result  := SameText(LStatus, 'SUCCESS');
        if SameText(LStatus, 'ERROR') then
          raise Exception.Create('LlamaParse: error al procesar el documento');
      finally
        LResult.Free;
      end;
    until Result or (LAttempts >= LLAMAPARSE_MAX_POLLS);
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 3: Obtiene el texto del documento parseado.
// ---------------------------------------------------------------------------
function TAiLlamaParseToolPdf.FetchResult(const AJobId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
begin
  Result  := '';
  LHeaders:= [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)];
  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get(
      LLAMAPARSE_BASE_URL + 'job/' + AJobId + '/result/' + FResultType,
      nil, LHeaders);

    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('LlamaParse result error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      // La clave del resultado coincide con el ResultType ('markdown','text','json')
      Result := LResult.GetValue<String>(FResultType, '');
      if Result.IsEmpty then
        // Fallback: algunos endpoints retornan en 'content' o 'result'
        if not LResult.TryGetValue<String>('content', Result) then
          LResult.TryGetValue<String>('result', Result);
    finally
      LResult.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TAiLlamaParseToolPdf.ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LJobId: String;
  LText : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('LlamaParse: archivo PDF no disponible', nil);
    Exit;
  end;

  try
    // Paso 1: Subir
    ReportState(acsConnecting, 'LlamaParse: subiendo PDF...');
    LJobId := UploadPdf(aMediaFile);
    if LJobId.IsEmpty then
      raise Exception.Create('LlamaParse: no se obtuvo job_id');

    // Paso 2: Polling
    ReportState(acsReasoning, 'LlamaParse: analizando documento...');
    if not PollJob(LJobId) then
      raise Exception.Create('LlamaParse: timeout esperando el resultado');

    // Paso 3: Obtener resultado
    LText := FetchResult(LJobId);
    if LText.IsEmpty then
      raise Exception.Create('LlamaParse: resultado vacío');

    ResMsg.Prompt := LText;
    ReportDataEnd(ResMsg, 'assistant', LText);

  except
    on E: Exception do
    begin
      ReportError(E.Message, E);
      ResMsg.Prompt := '';
    end;
  end;
end;

end.
