unit uMakerAi.ChatTools.Ideogram;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiIdeogramImageTool
// Implementacion de IAiImageTool usando Ideogram AI.
// https://developer.ideogram.ai/api-reference/api/generate-v2
//
// Ideogram es especialmente bueno generando texto dentro de imagenes.
// Soporta tipografia coherente y renderizado de letras de alta calidad.
//
// PATRON DE EJECUCION:
//   POST /generate -> JSON con URL de imagen -> descarga de la imagen
//   Es síncrono: una sola llamada HTTP, sin polling.
//
// DIFERENCIA DE AUTENTICACION vs otras tools:
//   Header: 'Api-Key: {key}' (sin guiones, sin Bearer, en CamelCase exacto)
//
// NOTA SOBRE MagicPromptOption:
//   'AUTO' = Ideogram mejora el prompt si lo considera necesario.
//   Esto puede cambiar el prompt original. Documentar en el demo.
//
// Env var requerida: IDEOGRAM_API_KEY
// Obtener en: https://developer.ideogram.ai/api/account

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiIdeogramImageTool = class(TAiImageToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FStyleType        : String;
    FAspectRatio      : String;
    FMagicPromptOption: String;
    FNegativePrompt   : String;
    FSeed             : Integer;

    function ResolveApiKey: String;
    function BuildRequestJSON(const APrompt: String): TJSONObject;
    function DownloadImage(const AURL: String): TBytes;
  protected
    procedure ExecuteImageGeneration(const APrompt: String;
                                     ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Ideogram. Soporta '@ENV_VAR' (default '@IDEOGRAM_API_KEY')
    // Header: 'Api-Key: {key}' — exactamente en CamelCase, sin Bearer
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo: 'V_2', 'V_2_TURBO', 'V_3' (default 'V_2')
    property Model: String read FModel write FModel;
    // Estilo: 'REALISTIC', 'DESIGN', 'RENDER_3D', 'ANIME', 'ILLUSTRATION'
    // (default 'REALISTIC')
    property StyleType: String read FStyleType write FStyleType;
    // Relación de aspecto: 'ASPECT_1_1', 'ASPECT_16_9', 'ASPECT_9_16',
    // 'ASPECT_4_3', 'ASPECT_3_4' (default 'ASPECT_1_1')
    property AspectRatio: String read FAspectRatio write FAspectRatio;
    // Opcion de mejora del prompt por IA: 'AUTO', 'ON', 'OFF' (default 'AUTO')
    // NOTA: 'AUTO' puede modificar el prompt original para mejores resultados
    property MagicPromptOption: String
             read FMagicPromptOption write FMagicPromptOption;
    // Elementos a evitar en la imagen (prompt negativo)
    property NegativePrompt: String read FNegativePrompt write FNegativePrompt;
    // Semilla para reproducibilidad (0 = aleatoria, default 0)
    property Seed: Integer read FSeed write FSeed default 0;
  end;

const
  IDEOGRAM_GENERATE_URL = 'https://api.ideogram.ai/generate';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiIdeogramImageTool]);
end;

constructor TAiIdeogramImageTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@IDEOGRAM_API_KEY';
  FModel             := 'V_2';
  FStyleType         := 'REALISTIC';
  FAspectRatio       := 'ASPECT_1_1';
  FMagicPromptOption := 'AUTO';
  FNegativePrompt    := '';
  FSeed              := 0;
end;

function TAiIdeogramImageTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para Ideogram.
// DIFERENCIA: la solicitud se anida en un objeto 'image_request'.
// ---------------------------------------------------------------------------
function TAiIdeogramImageTool.BuildRequestJSON(const APrompt: String): TJSONObject;
var
  JRequest: TJSONObject;
begin
  JRequest := TJSONObject.Create;
  JRequest.AddPair('prompt',              APrompt);
  JRequest.AddPair('model',              FModel);
  JRequest.AddPair('style_type',         FStyleType);
  JRequest.AddPair('aspect_ratio',       FAspectRatio);
  JRequest.AddPair('magic_prompt_option',FMagicPromptOption);

  if FNegativePrompt <> '' then
    JRequest.AddPair('negative_prompt', FNegativePrompt);
  if FSeed > 0 then
    JRequest.AddPair('seed', TJSONNumber.Create(FSeed));

  // La solicitud se envuelve en el campo 'image_request'
  Result := TJSONObject.Create;
  Result.AddPair('image_request', JRequest);
end;

function TAiIdeogramImageTool.DownloadImage(const AURL: String): TBytes;
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

// ---------------------------------------------------------------------------
// Genera la imagen: POST JSON -> obtiene URL -> descarga la imagen.
// Síncrono — sin polling.
// ---------------------------------------------------------------------------
procedure TAiIdeogramImageTool.ExecuteImageGeneration(const APrompt: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LRequest  : TJSONObject;
  LBody     : TStringStream;
  LHeaders  : TNetHeaders;
  LResult   : TJSONObject;
  JData     : TJSONArray;
  JItem     : TJSONObject;
  LImageUrl : String;
  LBytes    : TBytes;
  LImage    : TAiMediaFile;
begin
  if APrompt.IsEmpty then
  begin
    ReportError('Ideogram: prompt vacío', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Ideogram [' + FModel + ']: generando imagen...');

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(APrompt);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    // Header de autenticación: 'Api-Key' en CamelCase exacto
    LHeaders := [
      TNetHeader.Create('Api-Key',      ResolveApiKey),
      TNetHeader.Create('Content-Type', 'application/json')
    ];

    try
      LResponse := LClient.Post(IDEOGRAM_GENERATE_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Ideogram error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Ideogram: respuesta JSON invalida');
      try
        if not LResult.TryGetValue<TJSONArray>('data', JData) or
           (JData.Count = 0) then
          raise Exception.Create('Ideogram: sin resultados en la respuesta');

        JItem := TJSONObject(JData.Items[0]);
        LImageUrl := JItem.GetValue<String>('url', '');
        if LImageUrl.IsEmpty then
          raise Exception.Create('Ideogram: URL de imagen no disponible');
      finally
        LResult.Free;
      end;

      // Descargar la imagen desde la URL
      ReportState(acsConnecting, 'Ideogram: descargando imagen...');
      LBytes := DownloadImage(LImageUrl);
      if Length(LBytes) = 0 then
        raise Exception.Create('Ideogram: imagen descargada vacia');

      LImage := TAiMediaFile.Create(nil);
      LImage.FileName := 'image.jpg';  // Ideogram genera JPEG por defecto
      LImage.Stream.WriteBuffer(LBytes[0], Length(LBytes));
      LImage.Stream.Position := 0;
      ResMsg.MediaFiles.Add(LImage);

      ReportDataEnd(ResMsg, 'assistant', LImageUrl);

    except
      on E: Exception do
        ReportError(E.Message, E);
    end;
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

end.
