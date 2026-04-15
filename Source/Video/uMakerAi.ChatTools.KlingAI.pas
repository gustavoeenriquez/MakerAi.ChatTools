unit uMakerAi.ChatTools.KlingAI;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiKlingAIVideoTool
// Implementacion de IAiVideoTool usando Kling AI.
// https://docs.qingque.cn/d/home/eZQDhFyXP0YRKfXz17WrM8cO6
//
// Kling AI tiene la autenticación mas compleja de todos los tools de este paquete:
// requiere generar un JWT firmado con HMAC-SHA256 en cada llamada.
//
// AUTENTICACION JWT:
//   1. Header: Base64URL({"alg":"HS256","typ":"JWT"})
//   2. Payload: Base64URL({"iss": api_key, "exp": now+1800, "nbf": now-5})
//   3. Firma: HMAC-SHA256(header.payload, api_secret) → Base64URL
//   4. Token: header.payload.firma
//   Los tokens expiran a los 30 minutos.
//
// PATRON DE EJECUCION:
//   Paso 1: POST /v1/videos/text2video -> task_id
//   Paso 2: GET /v1/videos/text2video/{task_id} polling hasta task_status='succeed'
//   Paso 3: data.task_result.videos[0].url contiene la URL del video
//
// Env vars requeridas: KLINGAI_API_KEY + KLINGAI_API_SECRET
// Obtener en: https://platform.klingai.com/account/apikey

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  System.NetEncoding, System.DateUtils, System.Hash,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiKlingAIVideoTool = class(TAiVideoToolBase)
  private
    FApiKey        : String;
    FApiSecret     : String;
    FModel         : String;
    FDuration      : String;
    FAspectRatio   : String;
    FMode          : String;
    FCfgScale      : Single;
    FNegativePrompt: String;

    function ResolveApiKey: String;
    function ResolveApiSecret: String;
    function Base64UrlEncode(const ABytes: TBytes): String;
    function GenerateJWT: String;
    function GetAuthHeaders: TNetHeaders;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function SubmitTask(const APrompt: String): String;
    function PollTask(const ATaskId: String): String;
  protected
    procedure ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // Access Key ID de Kling AI. Soporta '@ENV_VAR' (default '@KLINGAI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Access Key Secret de Kling AI. Soporta '@ENV_VAR' (default '@KLINGAI_API_SECRET')
    property ApiSecret: String read FApiSecret write FApiSecret;
    // Modelo: 'kling-v1', 'kling-v1-5', 'kling-v2' (default 'kling-v2')
    property Model: String read FModel write FModel;
    // Duración: '5' o '10' segundos como string (default '5')
    property Duration: String read FDuration write FDuration;
    // Relación de aspecto: '16:9', '9:16', '1:1' (default '16:9')
    property AspectRatio: String read FAspectRatio write FAspectRatio;
    // Modo: 'std' (estándar), 'pro' (alta calidad, mas lento) (default 'std')
    property Mode: String read FMode write FMode;
    // Escala de configuración 0.0-1.0 (default 0.5)
    // Single no admite 'default' — asignado en constructor
    property CfgScale: Single read FCfgScale write FCfgScale;
    // Prompt negativo (default '')
    property NegativePrompt: String read FNegativePrompt write FNegativePrompt;
  end;

const
  KLINGAI_BASE_URL  = 'https://api.klingai.com/v1/videos/text2video';
  KLINGAI_POLL_MS   = 5000;
  KLINGAI_MAX_POLLS = 120;  // 10 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiKlingAIVideoTool]);
end;

constructor TAiKlingAIVideoTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@KLINGAI_API_KEY';
  FApiSecret      := '@KLINGAI_API_SECRET';
  FModel          := 'kling-v2';
  FDuration       := '5';
  FAspectRatio    := '16:9';
  FMode           := 'std';
  FCfgScale       := 0.5;
  FNegativePrompt := '';
end;

function TAiKlingAIVideoTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiKlingAIVideoTool.ResolveApiSecret: String;
begin
  Result := FApiSecret;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Base64URL encode: igual que Base64 pero usa '-' en lugar de '+'
// y '_' en lugar de '/', sin padding '='.
// ---------------------------------------------------------------------------
function TAiKlingAIVideoTool.Base64UrlEncode(const ABytes: TBytes): String;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(ABytes);
  Result := Result.Replace('+', '-', [rfReplaceAll]);
  Result := Result.Replace('/', '_', [rfReplaceAll]);
  Result := Result.Replace('=', '',  [rfReplaceAll]);
end;

// ---------------------------------------------------------------------------
// Genera el JWT para autenticación en Kling AI.
// Este es el metodo mas complejo del paquete — requiere firma HMAC-SHA256.
//
// Algoritmo:
//   header  = Base64URL({"alg":"HS256","typ":"JWT"})
//   payload = Base64URL({"iss":"api_key","exp":now+1800,"nbf":now-5})
//   data    = header + "." + payload
//   sig     = Base64URL(HMAC-SHA256(data, api_secret))
//   token   = data + "." + sig
// ---------------------------------------------------------------------------
function TAiKlingAIVideoTool.GenerateJWT: String;
var
  LNow     : Int64;
  JHeader  : TJSONObject;
  JPayload : TJSONObject;
  LHeader  : String;
  LPayload : String;
  LData    : String;
  LHmacHex : String;
  LHmacBytes: TBytes;
  I        : Integer;
begin
  // Timestamp Unix en UTC
  LNow := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False);

  JHeader  := TJSONObject.Create;
  JPayload := TJSONObject.Create;
  try
    JHeader.AddPair('alg', 'HS256');
    JHeader.AddPair('typ', 'JWT');

    JPayload.AddPair('iss', ResolveApiKey);
    JPayload.AddPair('exp', TJSONNumber.Create(LNow + 1800));
    JPayload.AddPair('nbf', TJSONNumber.Create(LNow - 5));

    LHeader  := Base64UrlEncode(TEncoding.UTF8.GetBytes(JHeader.ToJSON));
    LPayload := Base64UrlEncode(TEncoding.UTF8.GetBytes(JPayload.ToJSON));
    LData    := LHeader + '.' + LPayload;

    // HMAC-SHA256: THashSHA2.GetHMAC retorna hex lowercase
    LHmacHex := THashSHA2.GetHMAC(LData, ResolveApiSecret, SHA256);

    // Convertir hex a bytes para Base64URL
    SetLength(LHmacBytes, Length(LHmacHex) div 2);
    for I := 0 to High(LHmacBytes) do
      LHmacBytes[I] := StrToInt('$' + Copy(LHmacHex, I * 2 + 1, 2));

    Result := LData + '.' + Base64UrlEncode(LHmacBytes);
  finally
    JHeader.Free;
    JPayload.Free;
  end;
end;

function TAiKlingAIVideoTool.GetAuthHeaders: TNetHeaders;
begin
  Result := [
    TNetHeader.Create('Authorization', 'Bearer ' + GenerateJWT),
    TNetHeader.Create('Content-Type',  'application/json')
  ];
end;

function TAiKlingAIVideoTool.BuildRequestJSON(const APrompt: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model',        FModel);
  Result.AddPair('prompt',       APrompt);
  Result.AddPair('duration',     FDuration);
  Result.AddPair('aspect_ratio', FAspectRatio);
  Result.AddPair('mode',         FMode);
  Result.AddPair('cfg_scale',    TJSONNumber.Create(FCfgScale));

  if FNegativePrompt <> '' then
    Result.AddPair('negative_prompt', FNegativePrompt);
end;

// ---------------------------------------------------------------------------
// Paso 1: Envia la solicitud. Retorna el task_id.
// ---------------------------------------------------------------------------
function TAiKlingAIVideoTool.SubmitTask(const APrompt: String): String;
var
  LClient  : THTTPClient;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  JData    : TJSONObject;
begin
  Result   := '';
  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(APrompt);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LResponse := LClient.Post(KLINGAI_BASE_URL, LBody, nil, GetAuthHeaders);

    if not (LResponse.StatusCode in [200, 201]) then
      raise Exception.CreateFmt('Kling AI submit error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      if LResult.TryGetValue<TJSONObject>('data', JData) then
        Result := JData.GetValue<String>('task_id', '');
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
// Paso 2: Polling hasta task_status='succeed'. Retorna URL del video.
// Kling AI anida el estado en: response.data.task_status
// El video esta en: response.data.task_result.videos[0].url
// ---------------------------------------------------------------------------
function TAiKlingAIVideoTool.PollTask(const ATaskId: String): String;
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LResult   : TJSONObject;
  JData     : TJSONObject;
  JTaskResult: TJSONObject;
  JVideos   : TJSONArray;
  JVideo    : TJSONObject;
  LStatus   : String;
  LAttempts : Integer;
begin
  Result    := '';
  LStatus   := '';
  LAttempts := 0;
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(KLINGAI_POLL_MS);

      // Cada llamada al poll necesita un JWT fresco (GenerateJWT se llama aqui)
      LResponse := LClient.Get(KLINGAI_BASE_URL + '/' + ATaskId, nil, [
        TNetHeader.Create('Authorization', 'Bearer ' + GenerateJWT)
      ]);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        if not LResult.TryGetValue<TJSONObject>('data', JData) then Continue;

        LStatus := JData.GetValue<String>('task_status', '');
        if SameText(LStatus, 'succeed') then
        begin
          if JData.TryGetValue<TJSONObject>('task_result', JTaskResult) and
             JTaskResult.TryGetValue<TJSONArray>('videos', JVideos) and
             (JVideos.Count > 0) then
          begin
            JVideo := TJSONObject(JVideos.Items[0]);
            Result := JVideo.GetValue<String>('url', '');
          end;
        end
        else if SameText(LStatus, 'failed') then
          raise Exception.Create('Kling AI: generación de video fallida');
      finally
        LResult.Free;
      end;
    until (Result <> '') or SameText(LStatus, 'failed') or (LAttempts >= KLINGAI_MAX_POLLS);

    if (Result = '') and (LAttempts >= KLINGAI_MAX_POLLS) then
      raise Exception.Create('Kling AI: timeout esperando el video');
  finally
    LClient.Free;
  end;
end;

procedure TAiKlingAIVideoTool.ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage);
var
  LTaskId  : String;
  LVideoUrl: String;
begin
  if AskMsg.Prompt.IsEmpty then
  begin
    ReportError('Kling AI: prompt de video vacío', nil);
    Exit;
  end;

  try
    ReportState(acsConnecting, 'Kling AI [' + FModel + ']: enviando (JWT auth)...');
    LTaskId := SubmitTask(AskMsg.Prompt);
    if LTaskId.IsEmpty then
      raise Exception.Create('Kling AI: no se obtuvo task_id');

    ReportState(acsReasoning, 'Kling AI: generando video (~30-120 seg)...');
    LVideoUrl := PollTask(LTaskId);

    ResMsg.Prompt := LVideoUrl;
    ReportDataEnd(ResMsg, 'assistant', LVideoUrl);
  except
    on E: Exception do
    begin
      ReportError(E.Message, E);
      ResMsg.Prompt := '';
    end;
  end;
end;

end.
