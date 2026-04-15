unit uMakerAi.ChatTools.FishAudio;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiFishAudioTTSTool
// Implementacion de IAiSpeechTool (solo TTS) usando Fish Audio.
// https://docs.fish.audio/api-reference/text-to-speech
//
// Fish Audio es una plataforma open-source de clonación de voz y TTS.
// Ofrece voces muy naturales con baja latencia y soporte multilingue.
//
// ReferenceId: identifica el modelo de voz a usar. Puede ser:
//   - Un ID de voz del catalogo oficial de Fish Audio
//   - El ID de un modelo clonado propio (subido a la plataforma)
//
// NOTA: La documentacion oficial prioriza MessagePack como formato.
//   Este tool usa JSON para simplificar la implementación.
//   Ambos formatos son soportados por la API.
//
// NOTA: Solo TTS. ExecuteTranscription queda como no-op.
//
// Env var requerida: FISHAUDIO_API_KEY
// Obtener en: https://fish.audio/settings/api

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiFishAudioTTSTool = class(TAiSpeechToolBase)
  private
    FApiKey     : String;
    FReferenceId: String;
    FFormat     : String;
    FMp3Bitrate : Integer;
    FNormalize  : Boolean;
    FLatency    : String;

    function ResolveApiKey: String;
    function BuildRequestJSON(const AText: String): TJSONObject;
  protected
    procedure ExecuteSpeechGeneration(const AText: String;
                                      ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Fish Audio. Soporta '@ENV_VAR' (default '@FISHAUDIO_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // ID del modelo de voz en Fish Audio (requerido).
    // Obtener IDs en: https://fish.audio/model/
    property ReferenceId: String read FReferenceId write FReferenceId;
    // Formato de salida: 'mp3', 'wav', 'opus', 'flac', 'pcm' (default 'mp3')
    property Format: String read FFormat write FFormat;
    // Bitrate para MP3: 64, 128, 192 (default 128). Solo aplica si Format='mp3'
    property Mp3Bitrate: Integer read FMp3Bitrate write FMp3Bitrate default 128;
    // Si True, normaliza el volumen del audio (default True)
    property Normalize: Boolean read FNormalize write FNormalize default True;
    // Latencia: 'normal' (mas calidad) o 'balanced' (mas rápido) (default 'normal')
    property Latency: String read FLatency write FLatency;
  end;

const
  FISHAUDIO_TTS_URL = 'https://api.fish.audio/v1/tts';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiFishAudioTTSTool]);
end;

constructor TAiFishAudioTTSTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey      := '@FISHAUDIO_API_KEY';
  FReferenceId := '';   // Requerido — asignar antes de usar
  FFormat      := 'mp3';
  FMp3Bitrate  := 128;
  FNormalize   := True;
  FLatency     := 'normal';
end;

function TAiFishAudioTTSTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para Fish Audio.
// Mas simple que Cartesia: no hay sub-objetos para voz ni formato.
// ---------------------------------------------------------------------------
function TAiFishAudioTTSTool.BuildRequestJSON(const AText: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('text',         AText);
  Result.AddPair('reference_id', FReferenceId);
  Result.AddPair('format',       FFormat);
  Result.AddPair('normalize',    TJSONBool.Create(FNormalize));
  Result.AddPair('latency',      FLatency);

  if SameText(FFormat, 'mp3') then
    Result.AddPair('mp3_bitrate', TJSONNumber.Create(FMp3Bitrate));
end;

// ---------------------------------------------------------------------------
// TTS: POST a Fish Audio con JSON y recibe audio binario.
// ---------------------------------------------------------------------------
procedure TAiFishAudioTTSTool.ExecuteSpeechGeneration(const AText: String;
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
    ReportError('Fish Audio TTS: texto vacío', nil);
    Exit;
  end;

  if FReferenceId.IsEmpty then
  begin
    ReportError('Fish Audio TTS: ReferenceId no configurado. ' +
      'Asignar un ID de modelo de https://fish.audio/model/', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Fish Audio: generando audio [' + FLatency + ']...');

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AText);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    // Fish Audio usa 'Authorization: Bearer' (igual que OpenAI/Perplexity)
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  'application/json')
    ];

    try
      LResponse := LClient.Post(FISHAUDIO_TTS_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Fish Audio error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LBytes := LResponse.ContentAsBytes;
      if Length(LBytes) = 0 then
        raise Exception.Create('Fish Audio: audio vacío en la respuesta');

      LAudio := TAiMediaFile.Create(nil);
      LAudio.FileName := 'speech.' + FFormat;
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
