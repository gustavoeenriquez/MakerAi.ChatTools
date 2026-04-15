unit uMakerAi.ChatTools.GeminiVideo;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiGeminiVideoTool
// Implementacion de IAiVideoTool usando Google Veo via Gemini API.
//
// PATRON DE EJECUCION (Long Running Operation):
//   Paso 1: POST :predictLongRunning -> operation name
//   Paso 2: GET polling en /operations/{name} hasta done=true
//   Paso 3: response.generateVideoResponse.generatedSamples[0].video.uri
//
// AUTENTICACION: query param ?key={apikey}
// DESCARGA del video: requiere header x-goog-api-key (no el query param)
//
// RESULTADO: URI del video en ResMsg.Prompt
//
// Env var requerida: GEMINI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiGeminiVideoTool = class(TAiVideoToolBase)
  private
    FApiKey          : String;
    FModel           : String;
    FAspectRatio     : String;
    FResolution      : String;
    FDurationSeconds : Integer;
    FPersonGeneration: String;
    FNegativePrompt  : String;
    FSeed            : Integer;

    function ResolveApiKey: String;
    function GetSubmitUrl: String;
    function GetPollUrl(const AOperationName: String): String;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function SubmitGeneration(const APrompt: String): String;
    function PollOperation(const AOperationName: String): String;
  protected
    procedure ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Gemini/Google. Soporta '@ENV_VAR' (default '@GEMINI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo Veo: 'veo-2.0-generate-001', 'veo-3.0-generate-preview',
    // 'veo-3.1-generate-preview' (default 'veo-2.0-generate-001')
    property Model: String read FModel write FModel;
    // Relacion de aspecto: '16:9', '9:16' (default '16:9')
    property AspectRatio: String read FAspectRatio write FAspectRatio;
    // Resolucion: '720p', '1080p' (default '720p')
    property Resolution: String read FResolution write FResolution;
    // Duracion en segundos: 5, 6, 7, 8 (default 8)
    property DurationSeconds: Integer
             read FDurationSeconds write FDurationSeconds default 8;
    // Generación de personas: 'allow_all', 'allow_adult', 'dont_allow'
    // (default 'allow_all')
    property PersonGeneration: String
             read FPersonGeneration write FPersonGeneration;
    // Prompt negativo
    property NegativePrompt: String read FNegativePrompt write FNegativePrompt;
    // Semilla para reproducibilidad (0 = aleatoria, default 0)
    property Seed: Integer read FSeed write FSeed default 0;
  end;

const
  GEMINI_VIDEO_BASE  = 'https://generativelanguage.googleapis.com/v1beta/models/';
  GEMINI_OPS_BASE    = 'https://generativelanguage.googleapis.com/v1beta/';
  GEMINI_POLL_MS     = 10000;  // 10 segundos entre polls (video tarda 1-5 min)
  GEMINI_MAX_POLLS   = 60;     // 10 min max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiGeminiVideoTool]);
end;

constructor TAiGeminiVideoTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey           := '@GEMINI_API_KEY';
  FModel            := 'veo-2.0-generate-001';
  FAspectRatio      := '16:9';
  FResolution       := '720p';
  FDurationSeconds  := 8;
  FPersonGeneration := 'allow_all';
  FNegativePrompt   := '';
  FSeed             := 0;
end;

function TAiGeminiVideoTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiGeminiVideoTool.GetSubmitUrl: String;
begin
  Result := GEMINI_VIDEO_BASE + FModel +
            ':predictLongRunning?key=' + ResolveApiKey;
end;

function TAiGeminiVideoTool.GetPollUrl(const AOperationName: String): String;
begin
  // AOperationName ya incluye 'operations/xxx'
  Result := GEMINI_OPS_BASE + AOperationName + '?key=' + ResolveApiKey;
end;

function TAiGeminiVideoTool.BuildRequestJSON(const APrompt: String): TJSONObject;
var
  JInstance : TJSONObject;
  JInstances: TJSONArray;
  JParams   : TJSONObject;
begin
  JInstance := TJSONObject.Create;
  JInstance.AddPair('prompt', APrompt);

  JInstances := TJSONArray.Create;
  JInstances.AddElement(JInstance);

  JParams := TJSONObject.Create;
  JParams.AddPair('aspectRatio',      FAspectRatio);
  JParams.AddPair('resolution',       FResolution);
  JParams.AddPair('durationSeconds',  TJSONNumber.Create(FDurationSeconds));
  JParams.AddPair('personGeneration', FPersonGeneration);

  if FNegativePrompt <> '' then
    JParams.AddPair('negativePrompt', FNegativePrompt);
  if FSeed > 0 then
    JParams.AddPair('seed', TJSONNumber.Create(FSeed));

  Result := TJSONObject.Create;
  Result.AddPair('instances',  JInstances);
  Result.AddPair('parameters', JParams);
end;

// ---------------------------------------------------------------------------
// Paso 1: Envia la solicitud y obtiene el nombre de la operacion.
// La respuesta es: {"name": "operations/abc123xyz"}
// ---------------------------------------------------------------------------
function TAiGeminiVideoTool.SubmitGeneration(const APrompt: String): String;
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
    LResponse := LClient.Post(GetSubmitUrl, LBody, nil, [
      TNetHeader.Create('Content-Type', 'application/json')
    ]);

    if not (LResponse.StatusCode in [200, 201]) then
      raise Exception.CreateFmt('Gemini Veo submit error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      LResult.TryGetValue<String>('name', Result);
    finally
      LResult.Free;
    end;
  finally
    LBody.Free; LRequest.Free; LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 2: Polling hasta done=true. Retorna la URI del video.
// Estructura: response.generateVideoResponse.generatedSamples[0].video.uri
// ---------------------------------------------------------------------------
function TAiGeminiVideoTool.PollOperation(const AOperationName: String): String;
var
  LClient    : THTTPClient;
  LResponse  : IHTTPResponse;
  LResult    : TJSONObject;
  LDone      : Boolean;
  LAttempts  : Integer;
  JRespObj   : TJSONObject;
  JGenResp   : TJSONObject;
  JSamples   : TJSONArray;
  JSample    : TJSONObject;
  JVideo     : TJSONObject;
  JError     : TJSONObject;
  LErrorMsg  : String;
begin
  Result    := '';
  LDone     := False;
  LAttempts := 0;
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(GEMINI_POLL_MS);

      LResponse := LClient.Get(GetPollUrl(AOperationName));
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LResult.TryGetValue<Boolean>('done', LDone);

        if LResult.TryGetValue<TJSONObject>('error', JError) then
        begin
          JError.TryGetValue<String>('message', LErrorMsg);
          raise Exception.Create('Gemini Veo error: ' + LErrorMsg);
        end;

        if LDone then
        begin
          if LResult.TryGetValue<TJSONObject>('response', JRespObj) and
             JRespObj.TryGetValue<TJSONObject>('generateVideoResponse', JGenResp) and
             JGenResp.TryGetValue<TJSONArray>('generatedSamples', JSamples) and
             (JSamples.Count > 0) then
          begin
            JSample := TJSONObject(JSamples.Items[0]);
            if JSample.TryGetValue<TJSONObject>('video', JVideo) then
              JVideo.TryGetValue<String>('uri', Result);
          end;
        end;
      finally
        LResult.Free;
      end;
    until LDone or (LAttempts >= GEMINI_MAX_POLLS);

    if not LDone then
      raise Exception.Create('Gemini Veo: timeout esperando el video');
    if Result.IsEmpty then
      raise Exception.Create('Gemini Veo: URI del video no disponible');
  finally
    LClient.Free;
  end;
end;

procedure TAiGeminiVideoTool.ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage);
var
  LOpName  : String;
  LVideoUri: String;
begin
  if AskMsg.Prompt.IsEmpty then
  begin
    ReportError('Gemini Veo: prompt de video vacío', nil); Exit;
  end;

  try
    ReportState(acsConnecting, 'Gemini Veo [' + FModel + ']: iniciando generación...');
    LOpName := SubmitGeneration(AskMsg.Prompt);
    if LOpName.IsEmpty then
      raise Exception.Create('Gemini Veo: no se obtuvo operation name');

    ReportState(acsReasoning, 'Gemini Veo: generando video (~1-5 min)...');
    LVideoUri := PollOperation(LOpName);

    // NOTA: el URI de Gemini Veo requiere x-goog-api-key para descargar.
    // Ejemplo de descarga: GET {uri} con header 'x-goog-api-key: {key}'
    ResMsg.Prompt := LVideoUri;
    ReportDataEnd(ResMsg, 'assistant', LVideoUri);
  except
    on E: Exception do begin ReportError(E.Message, E); ResMsg.Prompt := ''; end;
  end;
end;

end.
