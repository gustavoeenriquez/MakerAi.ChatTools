unit uMakerAi.ChatTools.Cartesia;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiCartesiaTTSTool
// Implementacion de IAiSpeechTool (solo TTS) usando Cartesia AI.
// https://docs.cartesia.ai/api-reference/tts/bytes
//
// Cartesia esta optimizado para baja latencia — ideal para aplicaciones
// de voz en tiempo real y streaming.
//
// DIFERENCIA CLAVE vs ElevenLabs:
//   El campo 'output_format' es un OBJETO anidado, no un string:
//   "output_format": {"container": "mp3", "encoding": "mp3", "sample_rate": 44100}
//
// Requiere el header 'Cartesia-Version: 2024-06-10' en todas las peticiones.
//
// NOTA: Solo TTS. ExecuteTranscription queda como no-op.
//
// Env var requerida: CARTESIA_API_KEY
// Obtener en: https://play.cartesia.ai/settings/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiCartesiaTTSTool = class(TAiSpeechToolBase)
  private
    FApiKey    : String;
    FModelId   : String;
    FVoiceId   : String;
    FLanguage  : String;
    FContainer : String;
    FEncoding  : String;
    FSampleRate: Integer;

    function ResolveApiKey: String;
    function BuildRequestJSON(const AText: String): TJSONObject;
  protected
    procedure ExecuteSpeechGeneration(const AText: String;
                                      ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Cartesia. Soporta '@ENV_VAR' (default '@CARTESIA_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo TTS: 'sonic-2', 'sonic-english', 'sonic-multilingual' (default 'sonic-2')
    property ModelId: String read FModelId write FModelId;
    // ID de voz de Cartesia (ver: https://play.cartesia.ai/voice-library)
    property VoiceId: String read FVoiceId write FVoiceId;
    // Idioma: 'es', 'en', 'fr', 'de', etc. (default 'es')
    property Language: String read FLanguage write FLanguage;
    // Contenedor de audio: 'mp3', 'wav', 'ogg' (default 'mp3')
    property Container: String read FContainer write FContainer;
    // Encoding del audio: 'mp3', 'pcm_f32le', 'pcm_s16le' (default 'mp3')
    property Encoding: String read FEncoding write FEncoding;
    // Frecuencia de muestreo en Hz: 8000, 16000, 22050, 44100 (default 44100)
    property SampleRate: Integer read FSampleRate write FSampleRate default 44100;
  end;

const
  CARTESIA_TTS_URL     = 'https://api.cartesia.ai/tts/bytes';
  CARTESIA_API_VERSION = '2024-06-10';  // Header obligatorio

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiCartesiaTTSTool]);
end;

constructor TAiCartesiaTTSTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey     := '@CARTESIA_API_KEY';
  FModelId    := 'sonic-2';
  FVoiceId    := '';  // Asignar un VoiceId valido antes de usar
  FLanguage   := 'es';
  FContainer  := 'mp3';
  FEncoding   := 'mp3';
  FSampleRate := 44100;
end;

function TAiCartesiaTTSTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para Cartesia.
// DIFERENCIA CLAVE: output_format es un objeto anidado, no un string simple.
// voice tambien es un objeto: {"mode": "id", "id": "VoiceId"}
// ---------------------------------------------------------------------------
function TAiCartesiaTTSTool.BuildRequestJSON(const AText: String): TJSONObject;
var
  JVoice : TJSONObject;
  JFormat: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model_id',  FModelId);
  Result.AddPair('transcript', AText);
  Result.AddPair('language',  FLanguage);

  // La voz se especifica como objeto con modo 'id'
  JVoice := TJSONObject.Create;
  JVoice.AddPair('mode', 'id');
  JVoice.AddPair('id',   FVoiceId);
  Result.AddPair('voice', JVoice);

  // El formato de salida es un objeto (diferencia clave vs ElevenLabs y Fish Audio)
  JFormat := TJSONObject.Create;
  JFormat.AddPair('container',   FContainer);
  JFormat.AddPair('encoding',    FEncoding);
  JFormat.AddPair('sample_rate', TJSONNumber.Create(FSampleRate));
  Result.AddPair('output_format', JFormat);
end;

// ---------------------------------------------------------------------------
// TTS: POST a Cartesia y recibe audio binario.
// Requiere el header 'Cartesia-Version' ademas de la autenticación.
// ---------------------------------------------------------------------------
procedure TAiCartesiaTTSTool.ExecuteSpeechGeneration(const AText: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LHeaders : TNetHeaders;
  LBytes   : TBytes;
  LAudio   : TAiMediaFile;
begin
  if AText.IsEmpty then
  begin
    ReportError('Cartesia TTS: texto vacío', nil);
    Exit;
  end;

  if FVoiceId.IsEmpty then
  begin
    ReportError('Cartesia TTS: VoiceId no configurado. ' +
      'Asignar un ID valido de https://play.cartesia.ai/voice-library', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Cartesia: generando audio...');

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AText);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LHeaders := [
      TNetHeader.Create('X-API-Key',        ResolveApiKey),
      TNetHeader.Create('Cartesia-Version', CARTESIA_API_VERSION),
      TNetHeader.Create('Content-Type',     'application/json')
    ];

    try
      LResponse := LClient.Post(CARTESIA_TTS_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Cartesia error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LBytes := LResponse.ContentAsBytes;
      if Length(LBytes) = 0 then
        raise Exception.Create('Cartesia: audio vacío en la respuesta');

      LAudio := TAiMediaFile.Create(nil);
      LAudio.FileName := 'speech.' + FContainer;
      LAudio.Stream.WriteBuffer(LBytes[0], Length(LBytes));
      LAudio.Stream.Position := 0;
      ResMsg.MediaFiles.Add(LAudio);

      ReportDataEnd(ResMsg, 'assistant', '');

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
