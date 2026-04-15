unit uMakerAi.ChatTools.StabilityAI;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiStabilityAIImageTool
// Implementacion de IAiImageTool usando Stability AI (Stable Diffusion 3.x).
// https://platform.stability.ai/docs/api-reference#tag/Generate
//
// DIFERENCIA CLAVE vs fal.ai y Replicate:
//   El request usa multipart/form-data (no JSON).
//   La respuesta es el BINARIO de la imagen directamente (si Accept=image/*).
//   No hay polling — es una sola llamada sincrona.
//
// Endpoints por modelo:
//   SD3.5-large/medium/turbo -> POST /v2beta/stable-image/generate/sd3
//   'core'                   -> POST /v2beta/stable-image/generate/core
//
// Env var requerida: STABILITY_API_KEY
// Obtener en: https://platform.stability.ai/account/keys

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiStabilityAIImageTool = class(TAiImageToolBase)
  private
    FApiKey        : String;
    FModel         : String;
    FAspectRatio   : String;
    FOutputFormat  : String;
    FNegativePrompt: String;
    FStylePreset   : String;
    FSeed          : Integer;

    function ResolveApiKey: String;
    function GetEndpointUrl: String;
    function GetFormatExtension: String;
  protected
    procedure ExecuteImageGeneration(const APrompt: String;
                                     ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Stability AI. Soporta '@ENV_VAR' (default '@STABILITY_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo: 'sd3.5-large', 'sd3.5-medium', 'sd3-turbo', 'core' (default 'sd3.5-large')
    // El modelo determina el endpoint: sd3.x -> /sd3, core -> /core
    property Model: String read FModel write FModel;
    // Relación de aspecto: '1:1', '16:9', '9:16', '4:3', '3:4', '21:9' (default '1:1')
    property AspectRatio: String read FAspectRatio write FAspectRatio;
    // Formato de salida: 'png', 'jpeg', 'webp' (default 'png')
    property OutputFormat: String read FOutputFormat write FOutputFormat;
    // Prompt negativo — describe lo que NO debe aparecer en la imagen
    property NegativePrompt: String read FNegativePrompt write FNegativePrompt;
    // Preset de estilo (solo para modelo 'core'):
    // 'anime', 'photographic', 'digital-art', '3d-model', 'cinematic', etc.
    property StylePreset: String read FStylePreset write FStylePreset;
    // Semilla para reproducibilidad (0 = aleatoria, default 0)
    property Seed: Integer read FSeed write FSeed default 0;
  end;

const
  STABILITY_BASE_URL = 'https://api.stability.ai/v2beta/stable-image/generate/';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiStabilityAIImageTool]);
end;

constructor TAiStabilityAIImageTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@STABILITY_API_KEY';
  FModel          := 'sd3.5-large';
  FAspectRatio    := '1:1';
  FOutputFormat   := 'png';
  FNegativePrompt := '';
  FStylePreset    := '';
  FSeed           := 0;
end;

function TAiStabilityAIImageTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// El endpoint depende del modelo:
//   sd3.x -> .../sd3
//   core  -> .../core
// ---------------------------------------------------------------------------
function TAiStabilityAIImageTool.GetEndpointUrl: String;
begin
  if SameText(FModel, 'core') then
    Result := STABILITY_BASE_URL + 'core'
  else
    Result := STABILITY_BASE_URL + 'sd3';
end;

function TAiStabilityAIImageTool.GetFormatExtension: String;
begin
  if      SameText(FOutputFormat, 'jpeg') then Result := 'jpg'
  else if SameText(FOutputFormat, 'webp') then Result := 'webp'
  else                                         Result := 'png';
end;

// ---------------------------------------------------------------------------
// Ejecuta la generación: multipart/form-data -> respuesta binaria directa.
// DIFERENCIA vs otras Image tools: no hay JSON ni URL — el body ES la imagen.
// ---------------------------------------------------------------------------
procedure TAiStabilityAIImageTool.ExecuteImageGeneration(const APrompt: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LForm    : TMultipartFormData;
  LHeaders : TNetHeaders;
  LBytes   : TBytes;
  LImage   : TAiMediaFile;
begin
  if APrompt.IsEmpty then
  begin
    ReportError('Stability AI: prompt vacío', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Stability AI [' + FModel + ']: generando imagen...');

  LClient := THTTPClient.Create;
  LForm   := TMultipartFormData.Create;
  try
    // Campos del formulario multipart
    LForm.AddField('prompt',        APrompt);
    LForm.AddField('aspect_ratio',  FAspectRatio);
    LForm.AddField('output_format', FOutputFormat);

    if FSeed > 0 then
      LForm.AddField('seed', IntToStr(FSeed));
    if FNegativePrompt <> '' then
      LForm.AddField('negative_prompt', FNegativePrompt);
    // El campo 'model' solo aplica para el endpoint /sd3
    if not SameText(FModel, 'core') then
      LForm.AddField('model', FModel);
    // StylePreset solo aplica para el endpoint /core
    if SameText(FModel, 'core') and (FStylePreset <> '') then
      LForm.AddField('style_preset', FStylePreset);

    // Accept: image/* -> la respuesta ES el binario de la imagen
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Accept',        'image/*')
    ];

    try
      LResponse := LClient.Post(GetEndpointUrl, LForm, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Stability AI error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LBytes := LResponse.ContentAsBytes;
      if Length(LBytes) = 0 then
        raise Exception.Create('Stability AI: imagen vacia en la respuesta');

      LImage := TAiMediaFile.Create(nil);
      LImage.FileName := 'image.' + GetFormatExtension;
      LImage.Stream.WriteBuffer(LBytes[0], Length(LBytes));
      LImage.Stream.Position := 0;
      ResMsg.MediaFiles.Add(LImage);

      ReportDataEnd(ResMsg, 'assistant', '');

    except
      on E: Exception do
        ReportError(E.Message, E);
    end;
  finally
    LForm.Free;
    LClient.Free;
  end;
end;

end.
