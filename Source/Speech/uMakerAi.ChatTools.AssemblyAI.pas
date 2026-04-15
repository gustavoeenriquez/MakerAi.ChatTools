unit uMakerAi.ChatTools.AssemblyAI;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiAssemblyAISTTTool
// Implementacion de IAiSpeechTool (solo ExecuteTranscription) usando AssemblyAI.
// https://www.assemblyai.com/docs/api-reference/transcripts
//
// AssemblyAI es un servicio STT asíncrono en 3 pasos:
//   Paso 1: Subir el archivo de audio al storage de AssemblyAI
//   Paso 2: Enviar solicitud de transcripción con la URL del audio
//   Paso 3: Polling hasta que el status sea 'completed' o 'error'
//
// Diferenciadores vs otros STT:
//   - Speaker diarization (SpeakerLabels) — identifica hablantes distintos
//   - Sentiment analysis — analiza el sentimiento por utterance
//   - Auto chapters — divide el audio en capitulos con resumen
//   - Language detection automático si LanguageCode esta vacio
//
// NOTA: Solo implementa ExecuteTranscription. El metodo ExecuteSpeechGeneration
// queda como no-op (AssemblyAI no ofrece TTS).
//
// NOTA de threading: el polling bloquea el hilo que llama a ExecuteTranscription.
// En modo asíncrono (TAiChatConnection.Asynchronous=True), este metodo se
// ejecuta en un TTask, por lo que no bloquea la UI.
//
// Env var requerida: ASSEMBLYAI_API_KEY
// Obtener en: https://www.assemblyai.com/dashboard/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiAssemblyAISTTTool = class(TAiSpeechToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FLanguageCode     : String;
    FSpeakerLabels    : Boolean;
    FSentimentAnalysis: Boolean;
    FAutoChapters     : Boolean;
    FAutoHighlights   : Boolean;

    function  ResolveApiKey: String;
    function  GetAuthHeaders: TNetHeaders;
    function  UploadAudio(AStream: TStream): String;
    function  SubmitTranscription(const AUploadUrl: String): String;
    function  PollResult(const ATranscriptId: String): String;
  protected
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de AssemblyAI. Soporta '@ENV_VAR' (default '@ASSEMBLYAI_API_KEY')
    // IMPORTANTE: AssemblyAI usa 'Authorization: {key}' SIN prefijo 'Bearer'
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo de transcripción: 'best' (alta precision) o 'nano' (rápido y barato)
    property Model: String read FModel write FModel;
    // Codigo de idioma ISO 639-1: 'es', 'en', 'fr', etc.
    // Vacio = detección automatica de idioma
    property LanguageCode: String read FLanguageCode write FLanguageCode;
    // Si True, identifica y etiqueta hablantes distintos (Speaker A, Speaker B...)
    property SpeakerLabels: Boolean
             read FSpeakerLabels write FSpeakerLabels default False;
    // Si True, analiza el sentimiento de cada fragmento del audio
    property SentimentAnalysis: Boolean
             read FSentimentAnalysis write FSentimentAnalysis default False;
    // Si True, divide el audio en capitulos con titulo y resumen
    property AutoChapters: Boolean
             read FAutoChapters write FAutoChapters default False;
    // Si True, detecta y resalta las palabras y frases mas importantes
    property AutoHighlights: Boolean
             read FAutoHighlights write FAutoHighlights default False;
  end;

const
  ASSEMBLYAI_BASE_URL = 'https://api.assemblyai.com/v2';
  ASSEMBLYAI_POLL_INTERVAL_MS = 3000;  // 3 segundos entre intentos de polling
  ASSEMBLYAI_MAX_POLL_ATTEMPTS = 80;   // 80 * 3s = 4 minutos maximo

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiAssemblyAISTTTool]);
end;

constructor TAiAssemblyAISTTTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@ASSEMBLYAI_API_KEY';
  FModel             := 'best';
  FLanguageCode      := '';
  FSpeakerLabels     := False;
  FSentimentAnalysis := False;
  FAutoChapters      := False;
  FAutoHighlights    := False;
end;

function TAiAssemblyAISTTTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Header de autenticación para AssemblyAI.
// DIFERENCIA CLAVE: NO usa 'Bearer' — solo el valor de la clave directamente.
// ---------------------------------------------------------------------------
function TAiAssemblyAISTTTool.GetAuthHeaders: TNetHeaders;
begin
  Result := [TNetHeader.Create('Authorization', ResolveApiKey)];
end;

// ---------------------------------------------------------------------------
// Paso 1: Sube el audio al storage de AssemblyAI.
// Retorna la URL temporal del archivo subido.
// ---------------------------------------------------------------------------
function TAiAssemblyAISTTTool.UploadAudio(AStream: TStream): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LUpload  : TMemoryStream;
  LHeaders : TNetHeaders;
begin
  Result  := '';
  LClient := THTTPClient.Create;
  LUpload := TMemoryStream.Create;
  try
    AStream.Position := 0;
    LUpload.CopyFrom(AStream, AStream.Size);
    LUpload.Position := 0;

    LHeaders := GetAuthHeaders;
    SetLength(LHeaders, Length(LHeaders) + 1);
    LHeaders[High(LHeaders)] := TNetHeader.Create('Content-Type', 'application/octet-stream');

    LResponse := LClient.Post(ASSEMBLYAI_BASE_URL + '/upload', LUpload, nil, LHeaders);

    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('AssemblyAI upload error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      Result := LResult.GetValue<String>('upload_url', '');
    finally
      LResult.Free;
    end;
  finally
    LUpload.Free;
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 2: Envia la solicitud de transcripción con la URL del audio subido.
// Retorna el ID de la transcripción para usar en el polling.
// ---------------------------------------------------------------------------
function TAiAssemblyAISTTTool.SubmitTranscription(const AUploadUrl: String): String;
var
  LClient  : THTTPClient;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
begin
  Result   := '';
  LClient  := THTTPClient.Create;
  LRequest := TJSONObject.Create;
  LBody    := nil;
  try
    LRequest.AddPair('audio_url',    AUploadUrl);
    LRequest.AddPair('speech_model', FModel);

    if FLanguageCode <> '' then
      LRequest.AddPair('language_code', FLanguageCode)
    else
      LRequest.AddPair('language_detection', TJSONBool.Create(True));

    if FSpeakerLabels     then LRequest.AddPair('speaker_labels',     TJSONBool.Create(True));
    if FSentimentAnalysis then LRequest.AddPair('sentiment_analysis', TJSONBool.Create(True));
    if FAutoChapters      then LRequest.AddPair('auto_chapters',      TJSONBool.Create(True));
    if FAutoHighlights    then LRequest.AddPair('auto_highlights',    TJSONBool.Create(True));

    LBody := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);

    LHeaders := GetAuthHeaders;
    SetLength(LHeaders, Length(LHeaders) + 1);
    LHeaders[High(LHeaders)] := TNetHeader.Create('Content-Type', 'application/json');

    LResponse := LClient.Post(ASSEMBLYAI_BASE_URL + '/transcript', LBody, nil, LHeaders);

    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('AssemblyAI submit error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      Result := LResult.GetValue<String>('id', '');
    finally
      LResult.Free;
    end;
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 3: Polling hasta que la transcripción este completa.
// Intervalo: ASSEMBLYAI_POLL_INTERVAL_MS ms, maximo ASSEMBLYAI_MAX_POLL_ATTEMPTS intentos.
// ---------------------------------------------------------------------------
function TAiAssemblyAISTTTool.PollResult(const ATranscriptId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  LPollUrl : String;
begin
  Result   := '';
  LStatus  := '';
  LAttempts := 0;
  LPollUrl := ASSEMBLYAI_BASE_URL + '/transcript/' + ATranscriptId;
  LClient  := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(ASSEMBLYAI_POLL_INTERVAL_MS);

      LResponse := LClient.Get(LPollUrl, nil, GetAuthHeaders);
      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('AssemblyAI poll error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        if LStatus = 'completed' then
          Result := LResult.GetValue<String>('text', '')
        else if LStatus = 'error' then
          raise Exception.Create('AssemblyAI error: ' +
            LResult.GetValue<String>('error', 'transcripción fallida'));
      finally
        LResult.Free;
      end;
    until (LStatus = 'completed') or (LStatus = 'error') or
          (LAttempts >= ASSEMBLYAI_MAX_POLL_ATTEMPTS);

    if (LStatus <> 'completed') and (LStatus <> 'error') then
      raise Exception.Create('AssemblyAI: timeout esperando transcripción');
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Punto de entrada: ejecuta los 3 pasos de transcripción de AssemblyAI.
// ---------------------------------------------------------------------------
procedure TAiAssemblyAISTTTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LUploadUrl   : String;
  LTranscriptId: String;
  LText        : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('AssemblyAI: archivo de audio no disponible', nil);
    Exit;
  end;

  try
    // Paso 1: Subir audio
    ReportState(acsConnecting, 'AssemblyAI: subiendo audio...');
    LUploadUrl := UploadAudio(aMediaFile.Stream);
    if LUploadUrl = '' then
      raise Exception.Create('AssemblyAI: no se obtuvo URL de upload');

    // Paso 2: Solicitar transcripción
    ReportState(acsConnecting, 'AssemblyAI: iniciando transcripción [' + FModel + ']...');
    LTranscriptId := SubmitTranscription(LUploadUrl);
    if LTranscriptId = '' then
      raise Exception.Create('AssemblyAI: no se obtuvo ID de transcripción');

    // Paso 3: Esperar resultado
    ReportState(acsReasoning, 'AssemblyAI: procesando audio...');
    LText := PollResult(LTranscriptId);

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
