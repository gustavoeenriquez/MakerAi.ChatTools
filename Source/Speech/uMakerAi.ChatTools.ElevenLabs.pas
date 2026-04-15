unit uMakerAi.ChatTools.ElevenLabs;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiElevenLabsTool
// Implementacion de IAiSpeechTool (TTS + STT) usando ElevenLabs.
// https://elevenlabs.io/docs/api-reference
//
// El tool implementa ambos metodos:
//   ExecuteSpeechGeneration → TTS via /v1/text-to-speech/{voice_id}
//   ExecuteTranscription    → STT via /v1/speech-to-text (Scribe)
//
// Diferenciador: las voces mas naturales del mercado para TTS.
// Soporta clonación de voz (VoiceId del clon), multiples idiomas y
// ajuste fino de estabilidad/similitud/estilo.
//
// PATRON DE RESPUESTA TTS:
//   El body de la respuesta HTTP ES el audio binario directamente (no JSON).
//   Se almacena como TAiMediaFile en ResMsg.MediaFiles[0].
//
// PATRON DE RESPUESTA STT:
//   La respuesta es JSON: {"text": "...", "words": [...], "language_code": "..."}
//   El texto transcrito se escribe en ResMsg.Prompt.
//
// Env var requerida: ELEVENLABS_API_KEY
// Obtener en: https://elevenlabs.io/app/settings/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiElevenLabsTool = class(TAiSpeechToolBase)
  private
    FApiKey          : String;
    // TTS
    FVoiceId         : String;
    FTTSModel        : String;
    FStability       : Single;
    FSimilarityBoost : Single;
    FStyle           : Single;
    FUseSpeakerBoost : Boolean;
    FOutputFormat    : String;
    // STT
    FSTTModel        : String;
    FSTTLanguage     : String;
    FDiarizeNumSpeakers: Integer;

    function ResolveApiKey: String;
    function GetFormatExtension: String;
    function BuildTTSBody(const AText: String): TJSONObject;
  protected
    procedure ExecuteSpeechGeneration(const AText: String;
                                      ResMsg, AskMsg: TAiChatMessage); override;
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de ElevenLabs. Soporta '@ENV_VAR' (default '@ELEVENLABS_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;

    // --- TTS ---
    // ID de voz de ElevenLabs (default = George: 'JBFqnCBsd6RMkjVDRZzb')
    // Ver voces en: https://elevenlabs.io/app/voice-library
    property VoiceId: String read FVoiceId write FVoiceId;
    // Modelo TTS: 'eleven_multilingual_v2', 'eleven_turbo_v2_5' (default 'eleven_multilingual_v2')
    property TTSModel: String read FTTSModel write FTTSModel;
    // Estabilidad de la voz 0.0-1.0; mayor = mas monotona (default 0.5)
    // Nota: no admite directiva 'default' por ser Single
    property Stability: Single read FStability write FStability;
    // Similitud con la voz original 0.0-1.0; mayor = mas fiel (default 0.8)
    property SimilarityBoost: Single read FSimilarityBoost write FSimilarityBoost;
    // Estilo expresivo 0.0-1.0; 0=neutral, 1=muy expresivo (default 0.0)
    property Style: Single read FStyle write FStyle;
    // Si True, mejora la claridad de la voz con procesamiento adicional (default True)
    property UseSpeakerBoost: Boolean
             read FUseSpeakerBoost write FUseSpeakerBoost default True;
    // Formato de salida del audio: 'mp3_44100_128', 'pcm_16000', 'mp3_22050_32'
    // (default 'mp3_44100_128')
    property OutputFormat: String read FOutputFormat write FOutputFormat;

    // --- STT ---
    // Modelo STT: 'scribe_v1', 'scribe_v1_experimental' (default 'scribe_v1')
    property STTModel: String read FSTTModel write FSTTModel;
    // Codigo de idioma ISO: 'es', 'en', etc. Vacío = detección automatica
    property STTLanguage: String read FSTTLanguage write FSTTLanguage;
    // Numero de hablantes para diarización (0 = auto, 1..32)
    property DiarizeNumSpeakers: Integer
             read FDiarizeNumSpeakers write FDiarizeNumSpeakers default 0;
  end;

const
  ELEVENLABS_TTS_URL = 'https://api.elevenlabs.io/v1/text-to-speech/';
  ELEVENLABS_STT_URL = 'https://api.elevenlabs.io/v1/speech-to-text';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiElevenLabsTool]);
end;

constructor TAiElevenLabsTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@ELEVENLABS_API_KEY';
  FVoiceId           := 'JBFqnCBsd6RMkjVDRZzb';  // George (voz masculina natural)
  FTTSModel          := 'eleven_multilingual_v2';
  FStability         := 0.5;
  FSimilarityBoost   := 0.8;
  FStyle             := 0.0;
  FUseSpeakerBoost   := True;
  FOutputFormat      := 'mp3_44100_128';
  FSTTModel          := 'scribe_v1';
  FSTTLanguage       := '';
  FDiarizeNumSpeakers := 0;
end;

function TAiElevenLabsTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Deriva la extension del archivo de audio del OutputFormat.
// 'mp3_44100_128' -> 'mp3', 'pcm_16000' -> 'pcm', 'ulaw_8000' -> 'ulaw'
// ---------------------------------------------------------------------------
function TAiElevenLabsTool.GetFormatExtension: String;
begin
  if FOutputFormat.StartsWith('mp3')  then Result := 'mp3'
  else if FOutputFormat.StartsWith('pcm')  then Result := 'wav'
  else if FOutputFormat.StartsWith('opus') then Result := 'opus'
  else if FOutputFormat.StartsWith('aac')  then Result := 'aac'
  else if FOutputFormat.StartsWith('flac') then Result := 'flac'
  else if FOutputFormat.StartsWith('ulaw') then Result := 'ulaw'
  else Result := 'mp3';
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para la solicitud TTS.
// ---------------------------------------------------------------------------
function TAiElevenLabsTool.BuildTTSBody(const AText: String): TJSONObject;
var
  JSettings: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('text',     AText);
  Result.AddPair('model_id', FTTSModel);

  JSettings := TJSONObject.Create;
  JSettings.AddPair('stability',        TJSONNumber.Create(FStability));
  JSettings.AddPair('similarity_boost', TJSONNumber.Create(FSimilarityBoost));
  JSettings.AddPair('style',            TJSONNumber.Create(FStyle));
  JSettings.AddPair('use_speaker_boost',TJSONBool.Create(FUseSpeakerBoost));
  Result.AddPair('voice_settings', JSettings);
end;

// ---------------------------------------------------------------------------
// TTS: POST al endpoint de ElevenLabs y recibe el audio binario.
// La respuesta HTTP ES el audio — no JSON ni metadata.
// El audio se almacena como TAiMediaFile en ResMsg.MediaFiles.
// ---------------------------------------------------------------------------
procedure TAiElevenLabsTool.ExecuteSpeechGeneration(const AText: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LHeaders : TNetHeaders;
  LBytes   : TBytes;
  LAudio   : TAiMediaFile;
  LURL     : String;
begin
  if AText.IsEmpty then
  begin
    ReportError('ElevenLabs TTS: texto vacío', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'ElevenLabs TTS: generando audio...');

  LURL     := ELEVENLABS_TTS_URL + FVoiceId + '?output_format=' + FOutputFormat;
  LClient  := THTTPClient.Create;
  LRequest := BuildTTSBody(AText);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LHeaders := [
      TNetHeader.Create('xi-api-key',   ResolveApiKey),
      TNetHeader.Create('Content-Type', 'application/json'),
      TNetHeader.Create('Accept',       'audio/' + GetFormatExtension)
    ];

    try
      LResponse := LClient.Post(LURL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('ElevenLabs TTS error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      // La respuesta es audio binario — no parsear como JSON
      LBytes := LResponse.ContentAsBytes;
      if Length(LBytes) = 0 then
        raise Exception.Create('ElevenLabs TTS: respuesta de audio vacia');

      // Almacenar el audio como TAiMediaFile en el mensaje de respuesta
      LAudio := TAiMediaFile.Create(nil);
      LAudio.FileName := 'speech.' + GetFormatExtension;
      LAudio.Stream.WriteBuffer(LBytes[0], Length(LBytes));
      LAudio.Stream.Position := 0;
      ResMsg.MediaFiles.Add(LAudio);

      ReportDataEnd(ResMsg, 'assistant', '');

    except
      on E: Exception do
      begin
        ReportError(E.Message, E);
      end;
    end;
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// STT: POST multipart al endpoint Scribe de ElevenLabs.
// Diferencia vs Deepgram: usa multipart/form-data, no body binario directo.
// ---------------------------------------------------------------------------
procedure TAiElevenLabsTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LForm    : TMultipartFormData;
  LHeaders : TNetHeaders;
  LText    : String;
  LAudioCopy: TMemoryStream;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('ElevenLabs STT: archivo de audio no disponible', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'ElevenLabs Scribe: transcribiendo...');

  LClient   := THTTPClient.Create;
  LForm     := TMultipartFormData.Create;
  LAudioCopy := TMemoryStream.Create;
  try
    // Copiar el audio para enviar
    aMediaFile.Stream.Position := 0;
    LAudioCopy.CopyFrom(aMediaFile.Stream, aMediaFile.Stream.Size);
    LAudioCopy.Position := 0;

    // Campos multipart
    LForm.AddStream('file', LAudioCopy,
      ExtractFileName(aMediaFile.FileName), 'audio/mpeg');
    LForm.AddField('model_id', FSTTModel);
    if FSTTLanguage <> '' then
      LForm.AddField('language_code', FSTTLanguage);
    if FDiarizeNumSpeakers > 0 then
      LForm.AddField('num_speakers', IntToStr(FDiarizeNumSpeakers));

    LHeaders := [TNetHeader.Create('xi-api-key', ResolveApiKey)];

    try
      LResponse := LClient.Post(ELEVENLABS_STT_URL, LForm, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('ElevenLabs STT error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('ElevenLabs STT: respuesta JSON invalida');
      try
        LText := LResult.GetValue<String>('text', '');
      finally
        LResult.Free;
      end;

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);

    except
      on E: Exception do
      begin
        ReportError(E.Message, E);
        ResMsg.Prompt := '';
      end;
    end;
  finally
    LAudioCopy.Free;
    LForm.Free;
    LClient.Free;
  end;
end;

end.
