unit uMakerAi.ChatTools.RunwayML;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiRunwayMLVideoTool
// Implementacion de IAiVideoTool usando Runway ML Gen-4.
// https://docs.dev.runwayml.com/api
//
// PATRON DE EJECUCION (asíncrono con polling):
//   Paso 1: POST /v1/image_to_video -> task_id
//   Paso 2: GET /v1/tasks/{id} polling hasta status='SUCCEEDED'
//   Paso 3: output[0] contiene la URL del video MP4
//
// HEADERS CRITICOS:
//   Authorization: Bearer {key}
//   X-Runway-Version: 2024-11-06  ← OBLIGATORIO — sin este header: error 422
//
// RESULTADO: URL del video en ResMsg.Prompt
//
// Env var requerida: RUNWAYML_API_KEY
// Obtener en: https://app.runwayml.com/account/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiRunwayMLVideoTool = class(TAiVideoToolBase)
  private
    FApiKey        : String;
    FModel         : String;
    FDuration      : Integer;
    FRatio         : String;
    FWatermark     : Boolean;
    FSeed          : Integer;
    FNegativePrompt: String;

    function ResolveApiKey: String;
    function GetApiHeaders: TNetHeaders;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function SubmitTask(const APrompt: String): String;
    function PollTask(const ATaskId: String): String;
  protected
    procedure ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Runway. Soporta '@ENV_VAR' (default '@RUNWAYML_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo: 'gen4_turbo', 'gen3a_turbo' (default 'gen4_turbo')
    property Model: String read FModel write FModel;
    // Duración del video: 5 o 10 segundos (default 5)
    property Duration: Integer read FDuration write FDuration default 5;
    // Relación de aspecto: '1280:720', '720:1280', '1080:1920' (default '1280:720')
    property Ratio: String read FRatio write FRatio;
    // Si False, elimina el watermark de Runway (requiere plan de pago) (default False)
    property Watermark: Boolean read FWatermark write FWatermark default False;
    // Semilla para reproducibilidad (0 = aleatoria, default 0)
    property Seed: Integer read FSeed write FSeed default 0;
    // Elementos a evitar en el video (prompt negativo)
    property NegativePrompt: String read FNegativePrompt write FNegativePrompt;
  end;

const
  RUNWAY_BASE_URL    = 'https://api.dev.runwayml.com/v1/';
  RUNWAY_API_VERSION = '2024-11-06';  // OBLIGATORIO — version de la API
  RUNWAY_POLL_MS     = 5000;
  RUNWAY_MAX_POLLS   = 120;  // 120 * 5s = 10 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiRunwayMLVideoTool]);
end;

constructor TAiRunwayMLVideoTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@RUNWAYML_API_KEY';
  FModel          := 'gen4_turbo';
  FDuration       := 5;
  FRatio          := '1280:720';
  FWatermark      := False;
  FSeed           := 0;
  FNegativePrompt := '';
end;

function TAiRunwayMLVideoTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiRunwayMLVideoTool.GetApiHeaders: TNetHeaders;
begin
  Result := [
    TNetHeader.Create('Authorization',   'Bearer ' + ResolveApiKey),
    TNetHeader.Create('X-Runway-Version', RUNWAY_API_VERSION),
    TNetHeader.Create('Content-Type',    'application/json')
  ];
end;

function TAiRunwayMLVideoTool.BuildRequestJSON(const APrompt: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model',      FModel);
  Result.AddPair('promptText', APrompt);
  Result.AddPair('ratio',      FRatio);
  Result.AddPair('duration',   TJSONNumber.Create(FDuration));
  Result.AddPair('watermark',  TJSONBool.Create(FWatermark));

  if FSeed > 0 then
    Result.AddPair('seed', TJSONNumber.Create(FSeed));
  if FNegativePrompt <> '' then
    Result.AddPair('negativePrompt', FNegativePrompt);
end;

// ---------------------------------------------------------------------------
// Paso 1: Envia la solicitud de generación de video.
// Retorna el task_id para el polling.
// ---------------------------------------------------------------------------
function TAiRunwayMLVideoTool.SubmitTask(const APrompt: String): String;
var
  LClient  : THTTPClient;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
begin
  Result   := '';
  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(APrompt);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LResponse := LClient.Post(
      RUNWAY_BASE_URL + 'image_to_video', LBody, nil, GetApiHeaders);

    if not (LResponse.StatusCode in [200, 201]) then
      raise Exception.CreateFmt('Runway ML submit error %d: %s',
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
// Paso 2: Polling hasta SUCCEEDED. Retorna la URL del video o vacío.
// ---------------------------------------------------------------------------
function TAiRunwayMLVideoTool.PollTask(const ATaskId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  JOutput  : TJSONArray;
  LHeaders : TNetHeaders;
begin
  Result    := '';
  LStatus   := '';
  LAttempts := 0;
  LHeaders  := [
    TNetHeader.Create('Authorization',   'Bearer ' + ResolveApiKey),
    TNetHeader.Create('X-Runway-Version', RUNWAY_API_VERSION)
  ];
  LClient := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(RUNWAY_POLL_MS);

      LResponse := LClient.Get(RUNWAY_BASE_URL + 'tasks/' + ATaskId, nil, LHeaders);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        if SameText(LStatus, 'SUCCEEDED') then
        begin
          if LResult.TryGetValue<TJSONArray>('output', JOutput) and (JOutput.Count > 0) then
            Result := JOutput.Items[0].Value;
        end
        else if SameText(LStatus, 'FAILED') then
          raise Exception.Create('Runway ML: generación de video fallida');
      finally
        LResult.Free;
      end;
    until (Result <> '') or SameText(LStatus, 'FAILED') or (LAttempts >= RUNWAY_MAX_POLLS);

    if (Result = '') and (LAttempts >= RUNWAY_MAX_POLLS) then
      raise Exception.Create('Runway ML: timeout esperando el video');
  finally
    LClient.Free;
  end;
end;

procedure TAiRunwayMLVideoTool.ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage);
var
  LTaskId  : String;
  LVideoUrl: String;
begin
  if AskMsg.Prompt.IsEmpty then
  begin
    ReportError('Runway ML: prompt de video vacío', nil);
    Exit;
  end;

  try
    ReportState(acsConnecting, 'Runway ML [' + FModel + ']: enviando solicitud...');
    LTaskId := SubmitTask(AskMsg.Prompt);
    if LTaskId.IsEmpty then
      raise Exception.Create('Runway ML: no se obtuvo task_id');

    ReportState(acsReasoning, 'Runway ML: generando video (~30-90 seg)...');
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
