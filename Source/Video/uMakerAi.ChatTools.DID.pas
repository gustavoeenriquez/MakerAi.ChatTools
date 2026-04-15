unit uMakerAi.ChatTools.DID;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiDIDVideoTool
// Implementacion de IAiVideoTool usando D-ID (Talking Avatars).
// https://docs.d-id.com/reference/talks
//
// D-ID genera videos de avatares hablantes: combina una imagen de persona
// con un texto o audio para crear un video realista del avatar hablando.
// Es diferente a los demas tools de video — no genera escenas generativas,
// sino presentadores virtuales a partir de una imagen base.
//
// PATRON DE EJECUCION:
//   Paso 1: POST /talks -> talk_id (asíncrono)
//   Paso 2: GET /talks/{id} polling hasta status='done'
//   Paso 3: result_url contiene la URL del video MP4
//
// AUTENTICACION ESPECIAL:
//   Basic Auth: Base64(api_key:)  ← la api_key ES el usuario, password VACIO
//   'Authorization: Basic {Base64(key:)}'
//
// RESULTADO: URL del video en ResMsg.Prompt
//
// Env var requerida: DID_API_KEY
// Obtener en: https://studio.d-id.com/settings (API Keys)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiDIDVideoTool = class(TAiVideoToolBase)
  private
    FApiKey       : String;
    FDriverUrl    : String;
    FProviderType : String;
    FProviderVoice: String;
    FResultFormat : String;
    FStitch       : Boolean;

    function ResolveApiKey: String;
    function GetBasicAuthHeader: TNetHeader;
    function BuildRequestJSON(const AText: String): TJSONObject;
    function SubmitTalk(const AText: String): String;
    function PollTalk(const ATalkId: String): String;
  protected
    procedure ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de D-ID. Soporta '@ENV_VAR' (default '@DID_API_KEY')
    // Autenticación: Basic Auth — la key es el USUARIO, el password es VACIO
    property ApiKey: String read FApiKey write FApiKey;
    // URL de la imagen del avatar/presentador (puede ser URL publica o data URI)
    // Ejemplo: 'https://create-images-results.d-id.com/...png'
    property DriverUrl: String read FDriverUrl write FDriverUrl;
    // Proveedor de voz TTS: 'microsoft', 'elevenlabs', 'amazon' (default 'microsoft')
    property ProviderType: String read FProviderType write FProviderType;
    // ID de voz del proveedor.
    // Microsoft: 'es-MX-DaliaNeural', 'en-US-JennyNeural', etc.
    // (default 'es-MX-DaliaNeural')
    property ProviderVoice: String read FProviderVoice write FProviderVoice;
    // Formato del video: 'mp4', 'gif', 'webm' (default 'mp4')
    property ResultFormat: String read FResultFormat write FResultFormat;
    // Si True, integra el avatar en su imagen de fondo original (default False)
    property Stitch: Boolean read FStitch write FStitch default False;
  end;

const
  DID_API_BASE  = 'https://api.d-id.com/';
  DID_POLL_MS   = 4000;
  DID_MAX_POLLS = 75;  // 75 * 4s = 5 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiDIDVideoTool]);
end;

constructor TAiDIDVideoTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey        := '@DID_API_KEY';
  FDriverUrl     := '';  // Requerido — URL de la imagen del avatar
  FProviderType  := 'microsoft';
  FProviderVoice := 'es-MX-DaliaNeural';
  FResultFormat  := 'mp4';
  FStitch        := False;
end;

function TAiDIDVideoTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el header de autenticación Basic.
// DIFERENCIA CRITICA: la api_key ES el username y el password es VACIO.
// 'Authorization: Basic {Base64(api_key:)}'
// ---------------------------------------------------------------------------
function TAiDIDVideoTool.GetBasicAuthHeader: TNetHeader;
var
  LCredentials: String;
  LEncoded    : String;
begin
  LCredentials := ResolveApiKey + ':';  // key:  (sin password)
  LEncoded := TNetEncoding.Base64.EncodeBytesToString(
    TEncoding.UTF8.GetBytes(LCredentials));
  Result := TNetHeader.Create('Authorization', 'Basic ' + LEncoded);
end;

function TAiDIDVideoTool.BuildRequestJSON(const AText: String): TJSONObject;
var
  JScript  : TJSONObject;
  JProvider: TJSONObject;
  JConfig  : TJSONObject;
begin
  // Proveedor de voz
  JProvider := TJSONObject.Create;
  JProvider.AddPair('type',     FProviderType);
  JProvider.AddPair('voice_id', FProviderVoice);

  // Script del avatar
  JScript := TJSONObject.Create;
  JScript.AddPair('type',     'text');
  JScript.AddPair('input',    AText);
  JScript.AddPair('provider', JProvider);

  // Configuracion del video
  JConfig := TJSONObject.Create;
  JConfig.AddPair('stitch',        TJSONBool.Create(FStitch));
  JConfig.AddPair('result_format', FResultFormat);

  Result := TJSONObject.Create;
  Result.AddPair('source_url', FDriverUrl);
  Result.AddPair('script',     JScript);
  Result.AddPair('config',     JConfig);
end;

// ---------------------------------------------------------------------------
// Paso 1: Crea el talk (avatar video) en D-ID.
// Retorna el talk_id para el polling.
// ---------------------------------------------------------------------------
function TAiDIDVideoTool.SubmitTalk(const AText: String): String;
var
  LClient  : THTTPClient;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
begin
  Result   := '';
  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AText);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LResponse := LClient.Post(DID_API_BASE + 'talks', LBody, nil, [
      GetBasicAuthHeader,
      TNetHeader.Create('Content-Type', 'application/json'),
      TNetHeader.Create('Accept',       'application/json')
    ]);

    if not (LResponse.StatusCode in [200, 201]) then
      raise Exception.CreateFmt('D-ID submit error %d: %s',
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
// Paso 2: Polling hasta status='done'. Retorna result_url o vacío.
// ---------------------------------------------------------------------------
function TAiDIDVideoTool.PollTalk(const ATalkId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
begin
  Result    := '';
  LStatus   := '';
  LAttempts := 0;
  LClient   := THTTPClient.Create;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(DID_POLL_MS);

      LResponse := LClient.Get(DID_API_BASE + 'talks/' + ATalkId, nil, [
        GetBasicAuthHeader,
        TNetHeader.Create('Accept', 'application/json')
      ]);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        if SameText(LStatus, 'done') then
          Result := LResult.GetValue<String>('result_url', '')
        else if SameText(LStatus, 'error') then
          raise Exception.Create('D-ID: error al generar el video — ' +
            LResult.GetValue<String>('error', ''));
      finally
        LResult.Free;
      end;
    until (Result <> '') or SameText(LStatus, 'error') or (LAttempts >= DID_MAX_POLLS);

    if (Result = '') and (LAttempts >= DID_MAX_POLLS) then
      raise Exception.Create('D-ID: timeout esperando el video');
  finally
    LClient.Free;
  end;
end;

procedure TAiDIDVideoTool.ExecuteVideoGeneration(ResMsg, AskMsg: TAiChatMessage);
var
  LTalkId  : String;
  LVideoUrl: String;
begin
  if AskMsg.Prompt.IsEmpty then
  begin
    ReportError('D-ID: texto del avatar vacío (AskMsg.Prompt)', nil);
    Exit;
  end;

  if FDriverUrl.IsEmpty then
  begin
    ReportError('D-ID: DriverUrl no configurado. ' +
      'Asignar la URL de la imagen del avatar presentador.', nil);
    Exit;
  end;

  try
    ReportState(acsConnecting, 'D-ID: creando talk del avatar...');
    LTalkId := SubmitTalk(AskMsg.Prompt);
    if LTalkId.IsEmpty then
      raise Exception.Create('D-ID: no se obtuvo talk_id');

    ReportState(acsReasoning, 'D-ID: generando video (~15-60 seg)...');
    LVideoUrl := PollTalk(LTalkId);

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
