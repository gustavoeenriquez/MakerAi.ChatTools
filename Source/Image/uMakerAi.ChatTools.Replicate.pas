unit uMakerAi.ChatTools.Replicate;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiReplicateImageTool
// Implementacion de IAiImageTool usando Replicate.
// https://replicate.com/docs/reference/http#create-a-prediction
//
// Replicate es un marketplace de modelos open-source. Una sola API key
// da acceso a FLUX, Stable Diffusion XL, Kandinsky, y cientos mas.
//
// PATRON DE EJECUCION (igual que fal.ai — queue con polling):
//   Paso 1: POST /v1/models/{owner}/{model}/predictions -> prediction_id
//   Paso 2: GET /v1/predictions/{id} polling hasta status='succeeded'
//   Paso 3: Descargar imagen desde output[0] (URL)
//
// NOTA SOBRE ModelVersion:
//   Usar la forma corta 'owner/model' (Replicate resuelve la version oficial).
//   Para version especifica: 'owner/model:hash_version_completo'
//   Ejemplos:
//     'black-forest-labs/flux-schnell'  = FLUX Schnell (rápido)
//     'stability-ai/sdxl'              = SDXL
//     'black-forest-labs/flux-dev'     = FLUX Dev
//
// Env var requerida: REPLICATE_API_KEY
// Obtener en: https://replicate.com/account/api-tokens

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiReplicateImageTool = class(TAiImageToolBase)
  private
    FApiKey           : String;
    FModelVersion     : String;
    FImageWidth       : Integer;
    FImageHeight      : Integer;
    FNumOutputs       : Integer;
    FNumInferenceSteps: Integer;
    FGuidanceScale    : Single;
    FGoFast           : Boolean;
    FOutputFormat     : String;
    FOutputQuality    : Integer;

    function ResolveApiKey: String;
    function GetPredictionUrl: String;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function SubmitPrediction(const APrompt: String): String;
    function PollPrediction(const APredictionId: String): String;
    function DownloadImage(const AURL: String): TBytes;
  protected
    procedure ExecuteImageGeneration(const APrompt: String;
                                     ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Replicate. Soporta '@ENV_VAR' (default '@REPLICATE_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo en formato 'owner/model' o 'owner/model:version_hash'
    // (default 'black-forest-labs/flux-schnell')
    property ModelVersion: String read FModelVersion write FModelVersion;
    // Ancho de la imagen en píxeles (default 1024)
    property ImageWidth: Integer read FImageWidth write FImageWidth default 1024;
    // Alto de la imagen en píxeles (default 1024)
    property ImageHeight: Integer read FImageHeight write FImageHeight default 1024;
    // Numero de imagenes a generar (default 1)
    property NumOutputs: Integer read FNumOutputs write FNumOutputs default 1;
    // Pasos de inferencia: 4 (schnell), 28 (dev/pro) (default 4)
    property NumInferenceSteps: Integer
             read FNumInferenceSteps write FNumInferenceSteps default 4;
    // Escala de guia al prompt (default 3.5) — Single no admite 'default'
    property GuidanceScale: Single read FGuidanceScale write FGuidanceScale;
    // Si True, habilita cuantizacion para mayor velocidad (default True)
    property GoFast: Boolean read FGoFast write FGoFast default True;
    // Formato de salida: 'webp', 'jpg', 'png' (default 'webp')
    property OutputFormat: String read FOutputFormat write FOutputFormat;
    // Calidad de salida 0-100 (default 80, aplica a jpg/webp)
    property OutputQuality: Integer
             read FOutputQuality write FOutputQuality default 80;
  end;

const
  REPLICATE_API_BASE = 'https://api.replicate.com/v1/';
  REPLICATE_POLL_MS  = 3000;
  REPLICATE_MAX_POLLS= 60;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiReplicateImageTool]);
end;

constructor TAiReplicateImageTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@REPLICATE_API_KEY';
  FModelVersion      := 'black-forest-labs/flux-schnell';
  FImageWidth        := 1024;
  FImageHeight       := 1024;
  FNumOutputs        := 1;
  FNumInferenceSteps := 4;
  FGuidanceScale     := 3.5;
  FGoFast            := True;
  FOutputFormat      := 'webp';
  FOutputQuality     := 80;
end;

function TAiReplicateImageTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye la URL del endpoint de predicción.
// Replicate usa 'models/{owner}/{model}/predictions' para la forma corta.
// ---------------------------------------------------------------------------
function TAiReplicateImageTool.GetPredictionUrl: String;
var
  LModel: String;
  LColon: Integer;
begin
  // Si el ModelVersion tiene ':' es 'owner/model:hash' -> usar /v1/predictions
  LModel := FModelVersion;
  LColon := LModel.IndexOf(':');
  if LColon >= 0 then
    Result := REPLICATE_API_BASE + 'predictions'
  else
    Result := REPLICATE_API_BASE + 'models/' + LModel + '/predictions';
end;

function TAiReplicateImageTool.BuildRequestJSON(const APrompt: String): TJSONObject;
var
  JInput : TJSONObject;
  LColon : Integer;
begin
  JInput := TJSONObject.Create;
  JInput.AddPair('prompt',               APrompt);
  JInput.AddPair('width',                TJSONNumber.Create(FImageWidth));
  JInput.AddPair('height',               TJSONNumber.Create(FImageHeight));
  JInput.AddPair('num_outputs',          TJSONNumber.Create(FNumOutputs));
  JInput.AddPair('num_inference_steps',  TJSONNumber.Create(FNumInferenceSteps));
  JInput.AddPair('guidance_scale',       TJSONNumber.Create(FGuidanceScale));
  JInput.AddPair('go_fast',              TJSONBool.Create(FGoFast));
  JInput.AddPair('output_format',        FOutputFormat);
  JInput.AddPair('output_quality',       TJSONNumber.Create(FOutputQuality));

  Result := TJSONObject.Create;

  // Si hay ':' en el ModelVersion, incluir 'version' en el body
  LColon := FModelVersion.IndexOf(':');
  if LColon >= 0 then
    Result.AddPair('version', FModelVersion.Substring(LColon + 1));

  Result.AddPair('input', JInput);
end;

// ---------------------------------------------------------------------------
// Paso 1: Envia la predicción a Replicate.
// Retorna el prediction_id.
// ---------------------------------------------------------------------------
function TAiReplicateImageTool.SubmitPrediction(const APrompt: String): String;
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
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  'application/json'),
      TNetHeader.Create('Prefer',        'wait')  // solicita respuesta sincrona si posible
    ];

    LResponse := LClient.Post(GetPredictionUrl, LBody, nil, LHeaders);

    if not (LResponse.StatusCode in [200, 201]) then
      raise Exception.CreateFmt('Replicate submit error %d: %s',
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
// Paso 2: Polling hasta succeeded. Retorna la URL de la imagen o vacío.
// ---------------------------------------------------------------------------
function TAiReplicateImageTool.PollPrediction(const APredictionId: String): String;
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LResult   : TJSONObject;
  LStatus   : String;
  LAttempts : Integer;
  LPollUrl  : String;
  JOutput   : TJSONValue;
  JArr      : TJSONArray;
begin
  Result   := '';
  LStatus  := '';
  LPollUrl := REPLICATE_API_BASE + 'predictions/' + APredictionId;
  LClient  := THTTPClient.Create;
  LAttempts := 0;
  try
    repeat
      Inc(LAttempts);
      TThread.Sleep(REPLICATE_POLL_MS);

      LResponse := LClient.Get(LPollUrl, nil,
        [TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)]);
      if LResponse.StatusCode <> 200 then Break;

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then Continue;
      try
        LStatus := LResult.GetValue<String>('status', '');
        if SameText(LStatus, 'succeeded') then
        begin
          // 'output' puede ser string o array de strings
          if LResult.TryGetValue<TJSONValue>('output', JOutput) then
          begin
            if JOutput is TJSONArray then
            begin
              JArr := TJSONArray(JOutput);
              if JArr.Count > 0 then
                Result := JArr.Items[0].Value;
            end
            else
              Result := JOutput.Value;
          end;
        end
        else if SameText(LStatus, 'failed') or SameText(LStatus, 'canceled') then
          raise Exception.CreateFmt('Replicate: predicción %s', [LStatus]);
      finally
        LResult.Free;
      end;
    until (Result <> '') or SameText(LStatus, 'failed') or
          SameText(LStatus, 'canceled') or (LAttempts >= REPLICATE_MAX_POLLS);

    if (Result = '') and (LAttempts >= REPLICATE_MAX_POLLS) then
      raise Exception.Create('Replicate: timeout esperando la imagen');
  finally
    LClient.Free;
  end;
end;

function TAiReplicateImageTool.DownloadImage(const AURL: String): TBytes;
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

procedure TAiReplicateImageTool.ExecuteImageGeneration(const APrompt: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LPredictionId: String;
  LImageUrl    : String;
  LBytes       : TBytes;
  LImage       : TAiMediaFile;
begin
  if APrompt.IsEmpty then
  begin
    ReportError('Replicate: prompt vacío', nil);
    Exit;
  end;

  try
    // Paso 1
    ReportState(acsConnecting, 'Replicate [' + FModelVersion + ']: enviando...');
    LPredictionId := SubmitPrediction(APrompt);
    if LPredictionId.IsEmpty then
      raise Exception.Create('Replicate: no se obtuvo prediction_id');

    // Paso 2
    ReportState(acsReasoning, 'Replicate: generando imagen...');
    LImageUrl := PollPrediction(LPredictionId);
    if LImageUrl.IsEmpty then
      raise Exception.Create('Replicate: URL de imagen no disponible');

    // Paso 3
    ReportState(acsConnecting, 'Replicate: descargando imagen...');
    LBytes := DownloadImage(LImageUrl);
    if Length(LBytes) = 0 then
      raise Exception.Create('Replicate: imagen descargada vacia');

    LImage := TAiMediaFile.Create(nil);
    LImage.FileName := 'image.' + FOutputFormat;
    LImage.Stream.WriteBuffer(LBytes[0], Length(LBytes));
    LImage.Stream.Position := 0;
    ResMsg.MediaFiles.Add(LImage);

    ReportDataEnd(ResMsg, 'assistant', LImageUrl);

  except
    on E: Exception do
      ReportError(E.Message, E);
  end;
end;

end.
