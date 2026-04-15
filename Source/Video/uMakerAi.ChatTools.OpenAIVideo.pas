unit uMakerAi.ChatTools.OpenAIVideo;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiOpenAIVideoTool
// Implementacion de IAiVideoTool usando OpenAI Sora.
//
// PATRON DE EJECUCION (asincrono con polling):
//   Paso 1: POST /v1/videos (multipart) -> job id + status
//   Paso 2: GET /v1/videos/{id} polling hasta status='completed'
//   Paso 3: GET /v1/videos/{id}/content -> MP4 binario
//
// DIFERENCIA vs Gemini Veo:
//   - Request es multipart/form-data (no JSON)
//   - Autenticacion: Bearer (no query param)
//   - Resultado: binario descargable via API (requiere Bearer para descarga)
//
// RESULTADO: URL de descarga en ResMsg.Prompt
// Para descargar el video: GET {url} con 'Authorization: Bearer {key}'
//
// Env var requerida: OPENAI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiOpenAIVideoTool = class(TAiVideoToolBase)
  private
    FApiKey : String;
    FModel  : String;
    FSeconds: Integer;
    FSize   : String;

    function ResolveApiKey: String;
    function SubmitGeneration(const APrompt: String): String;
    function PollJob(const AJobId: String): Boolean;
    function GetVideoUrl(const AJobId: String): String;
  protected
    procedure ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de OpenAI. Soporta '@ENV_VAR' (default '@OPENAI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo Sora: 'sora', 'sora-2' (default 'sora')
    property Model: String read FModel write FModel;
    // Duracion del video en segundos: 4, 5, 10, 15, 20 (default 5)
    property Seconds: Integer read FSeconds write FSeconds default 5;
    // Resolucion: '480x270', '720x480', '1280x720', '1920x1080',
    // '720x1280', '1080x1920' (default '1280x720')
    property Size: String read FSize write FSize;
  end;

const
  SORA_VIDEOS_URL  = 'https://api.openai.com/v1/videos';
  SORA_POLL_MS     = 5000;
  SORA_MAX_POLLS   = 120;  // 10 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiOpenAIVideoTool]);
end;

constructor TAiOpenAIVideoTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey  := '@OPENAI_API_KEY';
  FModel   := 'sora';
  FSeconds := 5;
  FSize    := '1280x720';
end;

function TAiOpenAIVideoTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Paso 1: POST multipart a /v1/videos. Retorna el job id.
// DIFERENCIA vs Gemini: request es multipart/form-data (no JSON).
// ---------------------------------------------------------------------------
function TAiOpenAIVideoTool.SubmitGeneration(const APrompt: String): String;
var
  LClient  : THTTPClient;
  LForm    : TMultipartFormData;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
begin
  Result  := '';
  LClient := THTTPClient.Create;
  LForm   := TMultipartFormData.Create;
  try
    LForm.AddField('prompt',  APrompt);
    LForm.AddField('model',   FModel);
    LForm.AddField('seconds', IntToStr(FSeconds));
    LForm.AddField('size',    FSize);

    LResponse := LClient.Post(SORA_VIDEOS_URL, LForm, nil, [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)
    ]);

    if not (LResponse.StatusCode in [200, 201, 202]) then
      raise Exception.CreateFmt('Sora submit error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      LResult.TryGetValue<String>('id', Result);
    finally
      LResult.Free;
    end;
  finally
    LForm.Free; LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 2: Polling hasta status='completed'. Retorna True si completado.
// ---------------------------------------------------------------------------
function TAiOpenAIVideoTool.PollJob(const AJobId: String): Boolean;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  LHeaders : TNetHeaders;
begin
  Result    := False;
  LStatus   := '';
  LAttempts := 0;
  LHeaders  := [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)];
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(SORA_POLL_MS);

      LResponse := LClient.Get(SORA_VIDEOS_URL + '/' + AJobId, nil, LHeaders);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        Result  := SameText(LStatus, 'completed');
        if SameText(LStatus, 'failed') then
        begin
          var JErrObj: TJSONObject;
          var LErrMsg: String := 'error desconocido';
          if LResult.TryGetValue<TJSONObject>('error', JErrObj) then
            JErrObj.TryGetValue<String>('message', LErrMsg);
          raise Exception.Create('Sora: generación fallida — ' + LErrMsg);
        end;
      finally
        LResult.Free;
      end;
    until Result or SameText(LStatus, 'failed') or (LAttempts >= SORA_MAX_POLLS);

    if (not Result) and (LAttempts >= SORA_MAX_POLLS) then
      raise Exception.Create('Sora: timeout esperando el video');
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 3: Construye la URL de descarga del video.
// La descarga requiere: GET {url} con 'Authorization: Bearer {key}'
// ---------------------------------------------------------------------------
function TAiOpenAIVideoTool.GetVideoUrl(const AJobId: String): String;
begin
  // URL de descarga del video — requiere autenticación Bearer al descargar
  Result := SORA_VIDEOS_URL + '/' + AJobId + '/content';
end;

procedure TAiOpenAIVideoTool.ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage);
var
  LJobId   : String;
  LVideoUrl: String;
begin
  if AskMsg.Prompt.IsEmpty then
  begin
    ReportError('Sora: prompt de video vacío', nil); Exit;
  end;

  try
    ReportState(acsConnecting, 'Sora [' + FModel + ']: enviando solicitud...');
    LJobId := SubmitGeneration(AskMsg.Prompt);
    if LJobId.IsEmpty then
      raise Exception.Create('Sora: no se obtuvo job id');

    ReportState(acsReasoning, 'Sora: generando video (~1-5 min)...');
    PollJob(LJobId);

    // La URL de descarga requiere Bearer auth — incluir en Prompt para que
    // el caller pueda descargar con: GET {url} + Authorization: Bearer {key}
    LVideoUrl := GetVideoUrl(LJobId);
    ResMsg.Prompt := LVideoUrl;
    ReportDataEnd(ResMsg, 'assistant', LVideoUrl);
  except
    on E: Exception do begin ReportError(E.Message, E); ResMsg.Prompt := ''; end;
  end;
end;

end.
