unit uMakerAi.ChatTools.FalAi;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiFalAiImageTool
// Implementacion de IAiImageTool usando fal.ai.
// https://docs.fal.ai/api-reference
//
// fal.ai es un marketplace de modelos de IA con acceso a FLUX, Stable Diffusion
// y otros modelos de generación de imagen via una sola API.
//
// PATRON DE EJECUCION (queue-based):
//   Paso 1: POST al endpoint del modelo -> obtiene request_id
//   Paso 2: GET polling de status hasta 'COMPLETED'
//   Paso 3: GET resultado -> URL de la imagen
//   Paso 4: GET descarga de la imagen
//
// AUTENTICACION: 'Authorization: Key {api_key}' (no 'Bearer', no sin prefijo)
//
// Modelos recomendados:
//   'fal-ai/flux/schnell'       = mas rápido (4 pasos), ideal para demos
//   'fal-ai/flux/dev'           = equilibrio calidad/velocidad
//   'fal-ai/flux-pro/v1.1'      = mayor calidad, mas lento y costoso
//   'fal-ai/stable-diffusion-v3-medium' = Stable Diffusion 3 medium
//
// Env var requerida: FAL_API_KEY
// Obtener en: https://fal.ai/dashboard/keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiFalAiImageTool = class(TAiImageToolBase)
  private
    FApiKey            : String;
    FModelPath         : String;
    FImageSize         : String;
    FNumInferenceSteps : Integer;
    FGuidanceScale     : Single;
    FNumImages         : Integer;
    FEnableSafetyChecker: Boolean;
    FOutputFormat      : String;

    function ResolveApiKey: String;
    function GetQueueBaseUrl: String;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function SubmitRequest(const APrompt: String): String;
    function PollStatus(const ARequestId: String): Boolean;
    function FetchResult(const ARequestId: String): String;
    function DownloadImage(const AURL: String): TBytes;
  protected
    procedure ExecuteImageGeneration(const APrompt: String;
                                     ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de fal.ai. Soporta '@ENV_VAR' (default '@FAL_API_KEY')
    // AUTENTICACION: 'Authorization: Key {key}' (diferente a Bearer)
    property ApiKey: String read FApiKey write FApiKey;
    // Ruta del modelo: 'fal-ai/flux/schnell', 'fal-ai/flux-pro/v1.1', etc.
    property ModelPath: String read FModelPath write FModelPath;
    // Tamano de imagen: 'square_hd', 'square', 'portrait_4_3', 'landscape_4_3'
    // 'portrait_16_9', 'landscape_16_9' (default 'square_hd' = 1024x1024)
    property ImageSize: String read FImageSize write FImageSize;
    // Pasos de inferencia: 4 (schnell), 28 (dev/pro) (default 4)
    property NumInferenceSteps: Integer
             read FNumInferenceSteps write FNumInferenceSteps default 4;
    // Escala de guia: mayor = mas fiel al prompt (default 3.5)
    // Nota: Single no admite 'default' — asignado en constructor
    property GuidanceScale: Single read FGuidanceScale write FGuidanceScale;
    // Numero de imagenes a generar (default 1)
    property NumImages: Integer read FNumImages write FNumImages default 1;
    // Si True, aplica el filtro de seguridad del modelo (default True)
    property EnableSafetyChecker: Boolean
             read FEnableSafetyChecker write FEnableSafetyChecker default True;
    // Formato de salida: 'jpeg', 'png', 'webp' (default 'jpeg')
    property OutputFormat: String read FOutputFormat write FOutputFormat;
  end;

const
  FAL_QUEUE_BASE  = 'https://queue.fal.run/';
  FAL_POLL_MS     = 3000;
  FAL_MAX_POLLS   = 60;  // 60 * 3s = 3 minutos max

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiFalAiImageTool]);
end;

constructor TAiFalAiImageTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey             := '@FAL_API_KEY';
  FModelPath          := 'fal-ai/flux/schnell';
  FImageSize          := 'square_hd';
  FNumInferenceSteps  := 4;
  FGuidanceScale      := 3.5;
  FNumImages          := 1;
  FEnableSafetyChecker:= True;
  FOutputFormat       := 'jpeg';
end;

function TAiFalAiImageTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiFalAiImageTool.GetQueueBaseUrl: String;
begin
  // URL base del queue para el modelo seleccionado
  Result := FAL_QUEUE_BASE + FModelPath;
end;

function TAiFalAiImageTool.GetAuthHeaders: TNetHeaders;
begin
  // DIFERENCIA CLAVE: fal.ai usa 'Key' no 'Bearer'
  Result := [TNetHeader.Create('Authorization', 'Key ' + ResolveApiKey)];
end;

function TAiFalAiImageTool.BuildRequestJSON(const APrompt: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('prompt',               APrompt);
  Result.AddPair('image_size',           FImageSize);
  Result.AddPair('num_inference_steps',  TJSONNumber.Create(FNumInferenceSteps));
  Result.AddPair('guidance_scale',       TJSONNumber.Create(FGuidanceScale));
  Result.AddPair('num_images',           TJSONNumber.Create(FNumImages));
  Result.AddPair('enable_safety_checker',TJSONBool.Create(FEnableSafetyChecker));
  Result.AddPair('output_format',        FOutputFormat);
end;

// ---------------------------------------------------------------------------
// Paso 1: Envia la solicitud al queue de fal.ai.
// Retorna el request_id para el polling.
// ---------------------------------------------------------------------------
function TAiFalAiImageTool.SubmitRequest(const APrompt: String): String;
var
  LClient  : THTTPClient;
  LBody    : TStringStream;
  LRequest : TJSONObject;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
begin
  Result   := '';
  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(APrompt);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LHeaders := GetAuthHeaders;
    SetLength(LHeaders, Length(LHeaders) + 1);
    LHeaders[High(LHeaders)] := TNetHeader.Create('Content-Type', 'application/json');

    LResponse := LClient.Post(GetQueueBaseUrl, LBody, nil, LHeaders);

    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('fal.ai submit error %d: %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if Assigned(LResult) then
    try
      Result := LResult.GetValue<String>('request_id', '');
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
// Paso 2: Polling hasta que el status sea 'COMPLETED'.
// Retorna True si completado, False si timeout o error.
// ---------------------------------------------------------------------------
function TAiFalAiImageTool.PollStatus(const ARequestId: String): Boolean;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LStatus  : String;
  LAttempts: Integer;
  LPollUrl : String;
begin
  Result   := False;
  LPollUrl := GetQueueBaseUrl + '/requests/' + ARequestId + '/status';
  LClient  := THTTPClient.Create;
  LAttempts := 0;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(FAL_POLL_MS);

      LResponse := LClient.Get(LPollUrl, nil, GetAuthHeaders);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        Result  := SameText(LStatus, 'COMPLETED');
      finally
        LResult.Free;
      end;
    until Result or (LAttempts >= FAL_MAX_POLLS);
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 3: Obtiene la URL de la imagen del resultado.
// ---------------------------------------------------------------------------
function TAiFalAiImageTool.FetchResult(const ARequestId: String): String;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  JImages  : TJSONArray;
  JImage   : TJSONObject;
begin
  Result  := '';
  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get(
      GetQueueBaseUrl + '/requests/' + ARequestId, nil, GetAuthHeaders);

    if LResponse.StatusCode <> 200 then Exit;

    LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if not Assigned(LResult) then Exit;
    try
      if LResult.TryGetValue<TJSONArray>('images', JImages) and
         (JImages.Count > 0) then
      begin
        JImage := TJSONObject(JImages.Items[0]);
        Result := JImage.GetValue<String>('url', '');
      end;
    finally
      LResult.Free;
    end;
  finally
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Paso 4: Descarga la imagen desde la URL.
// ---------------------------------------------------------------------------
function TAiFalAiImageTool.DownloadImage(const AURL: String): TBytes;
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
begin
  SetLength(Result, 0);
  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get(AURL);
    if LResponse.StatusCode = 200 then
      Result := LResponse.ContentAsBytes;
  finally
    LClient.Free;
  end;
end;

procedure TAiFalAiImageTool.ExecuteImageGeneration(const APrompt: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LRequestId: String;
  LImageUrl : String;
  LBytes    : TBytes;
  LImage    : TAiMediaFile;
begin
  if APrompt.IsEmpty then
  begin
    ReportError('fal.ai: prompt vacío', nil);
    Exit;
  end;

  try
    // Paso 1: Enviar al queue
    ReportState(acsConnecting, 'fal.ai [' + FModelPath + ']: enviando solicitud...');
    LRequestId := SubmitRequest(APrompt);
    if LRequestId.IsEmpty then
      raise Exception.Create('fal.ai: no se obtuvo request_id');

    // Paso 2: Polling
    ReportState(acsReasoning, 'fal.ai: generando imagen...');
    if not PollStatus(LRequestId) then
      raise Exception.Create('fal.ai: timeout esperando la imagen');

    // Paso 3: Obtener URL
    LImageUrl := FetchResult(LRequestId);
    if LImageUrl.IsEmpty then
      raise Exception.Create('fal.ai: URL de imagen no disponible');

    // Paso 4: Descargar imagen
    ReportState(acsConnecting, 'fal.ai: descargando imagen...');
    LBytes := DownloadImage(LImageUrl);
    if Length(LBytes) = 0 then
      raise Exception.Create('fal.ai: imagen descargada vacia');

    LImage := TAiMediaFile.Create(nil);
    LImage.FileName := 'image.' + FOutputFormat;
    LImage.Stream.WriteBuffer(LBytes[0], Length(LBytes));
    LImage.Stream.Position := 0;
    ResMsg.MediaFiles.Add(LImage);

    ReportDataEnd(ResMsg, 'assistant', LImageUrl);

  except
    on E: Exception do
    begin
      ReportError(E.Message, E);
    end;
  end;
end;

end.
