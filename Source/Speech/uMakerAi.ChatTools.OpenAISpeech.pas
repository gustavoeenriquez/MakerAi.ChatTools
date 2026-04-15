unit uMakerAi.ChatTools.OpenAISpeech;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiOpenAISpeechTool
// Implementacion de IAiSpeechTool usando las APIs nativas de OpenAI.
//
// ExecuteSpeechGeneration → TTS via /v1/audio/speech
//   Modelos: tts-1, tts-1-hd, gpt-4o-mini-tts
//   Voces: alloy, echo, fable, onyx, shimmer, nova
//   Response: binario de audio (MP3 por defecto)
//
// ExecuteTranscription → STT via /v1/audio/transcriptions (Whisper)
//   Modelos: whisper-1, gpt-4o-transcribe, gpt-4o-mini-transcribe
//   Request: multipart/form-data con el archivo de audio
//   Response: JSON {"text": "..."}
//
// Esta es la implementación standalone del ChatTools package, sin depender
// de TAiOpenAiAudio interno de MakerAI.
//
// Env var requerida: OPENAI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.Mime,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiOpenAISpeechTool = class(TAiSpeechToolBase)
  private
    FApiKey        : String;
    // TTS
    FTTSModel      : String;
    FVoice         : String;
    FResponseFormat: String;
    FSpeed         : Single;
    // STT
    FSTTModel      : String;
    FLanguage      : String;
    FSTTFormat     : String;

    function ResolveApiKey: String;
    function GetMimeType(const AFileName: String): String;
  protected
    procedure ExecuteSpeechGeneration(const AText: String;
                                      ResMsg, AskMsg: TAiChatMessage); override;
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de OpenAI. Soporta '@ENV_VAR' (default '@OPENAI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo TTS: 'tts-1', 'tts-1-hd', 'gpt-4o-mini-tts' (default 'tts-1')
    property TTSModel: String read FTTSModel write FTTSModel;
    // Voz: 'alloy', 'echo', 'fable', 'onyx', 'shimmer', 'nova' (default 'alloy')
    property Voice: String read FVoice write FVoice;
    // Formato de audio: 'mp3', 'opus', 'aac', 'flac', 'wav', 'pcm' (default 'mp3')
    property ResponseFormat: String read FResponseFormat write FResponseFormat;
    // Velocidad de habla 0.25-4.0 (default 1.0) — Single, asignado en constructor
    property Speed: Single read FSpeed write FSpeed;
    // Modelo STT: 'whisper-1', 'gpt-4o-transcribe' (default 'whisper-1')
    property STTModel: String read FSTTModel write FSTTModel;
    // Idioma del audio ISO-639-1: 'es', 'en', etc. (vacío = autodeteccion)
    property Language: String read FLanguage write FLanguage;
    // Formato de respuesta STT: 'json', 'text', 'srt', 'vtt' (default 'json')
    property STTFormat: String read FSTTFormat write FSTTFormat;
  end;

const
  OPENAI_TTS_URL = 'https://api.openai.com/v1/audio/speech';
  OPENAI_STT_URL = 'https://api.openai.com/v1/audio/transcriptions';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiOpenAISpeechTool]);
end;

constructor TAiOpenAISpeechTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@OPENAI_API_KEY';
  FTTSModel       := 'tts-1';
  FVoice          := 'alloy';
  FResponseFormat := 'mp3';
  FSpeed          := 1.0;
  FSTTModel       := 'whisper-1';
  FLanguage       := '';
  FSTTFormat      := 'json';
end;

function TAiOpenAISpeechTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiOpenAISpeechTool.GetMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      Ext = '.mp3'  then Result := 'audio/mpeg'
  else if Ext = '.wav'  then Result := 'audio/wav'
  else if Ext = '.m4a'  then Result := 'audio/mp4'
  else if Ext = '.ogg'  then Result := 'audio/ogg'
  else if Ext = '.flac' then Result := 'audio/flac'
  else if Ext = '.webm' then Result := 'audio/webm'
  else                       Result := 'audio/mpeg';
end;

// ---------------------------------------------------------------------------
// TTS: POST JSON -> binario de audio en el body de la respuesta.
// ---------------------------------------------------------------------------
procedure TAiOpenAISpeechTool.ExecuteSpeechGeneration(const AText: String;
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
  if AText.IsEmpty then begin ReportError('OpenAI TTS: texto vacío', nil); Exit; end;

  ReportState(acsConnecting, 'OpenAI TTS [' + FTTSModel + '/' + FVoice + ']: generando...');

  LClient  := THTTPClient.Create;
  LRequest := TJSONObject.Create;
  LBody    := nil;
  try
    LRequest.AddPair('model',           FTTSModel);
    LRequest.AddPair('input',           AText);
    LRequest.AddPair('voice',           FVoice);
    LRequest.AddPair('response_format', FResponseFormat);
    LRequest.AddPair('speed',           TJSONNumber.Create(FSpeed));

    LBody := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  'application/json')
    ];

    try
      LResponse := LClient.Post(OPENAI_TTS_URL, LBody, nil, LHeaders);
      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('OpenAI TTS error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LBytes := LResponse.ContentAsBytes;
      if Length(LBytes) = 0 then
        raise Exception.Create('OpenAI TTS: audio vacío');

      LAudio := TAiMediaFile.Create(nil);
      LAudio.FileName := 'speech.' + FResponseFormat;
      LAudio.Stream.WriteBuffer(LBytes[0], Length(LBytes));
      LAudio.Stream.Position := 0;
      ResMsg.MediaFiles.Add(LAudio);
      ReportDataEnd(ResMsg, 'assistant', '');
    except
      on E: Exception do ReportError(E.Message, E);
    end;
  finally
    LBody.Free; LRequest.Free; LClient.Free;
  end;
end;

// ---------------------------------------------------------------------------
// STT: POST multipart -> JSON {"text": "..."}
// Igual patron que ElevenLabs STT pero con whisper-1 de OpenAI.
// ---------------------------------------------------------------------------
procedure TAiOpenAISpeechTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LForm    : TMultipartFormData;
  LCopy    : TMemoryStream;
  LResult  : TJSONObject;
  LText    : String;
  LFileName: String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('OpenAI STT: archivo de audio no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'OpenAI STT [' + FSTTModel + ']: transcribiendo...');

  LClient := THTTPClient.Create;
  LForm   := TMultipartFormData.Create;
  LCopy   := TMemoryStream.Create;
  try
    aMediaFile.Stream.Position := 0;
    LCopy.CopyFrom(aMediaFile.Stream, aMediaFile.Stream.Size);
    LCopy.Position := 0;

    LFileName := ExtractFileName(aMediaFile.FileName);
    if LFileName = '' then LFileName := 'audio.mp3';

    LForm.AddStream('file',  LCopy, LFileName, GetMimeType(LFileName));
    LForm.AddField('model',  FSTTModel);
    LForm.AddField('response_format', FSTTFormat);
    if FLanguage <> '' then LForm.AddField('language', FLanguage);

    try
      LResponse := LClient.Post(OPENAI_STT_URL, LForm, nil, [
        TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey)
      ]);
      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('OpenAI STT error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      if SameText(FSTTFormat, 'json') then
      begin
        LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if Assigned(LResult) then
        try
          LText := LResult.GetValue<String>('text', '');
        finally
          LResult.Free;
        end;
      end
      else
        LText := LResponse.ContentAsString;

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);
    except
      on E: Exception do begin ReportError(E.Message, E); ResMsg.Prompt := ''; end;
    end;
  finally
    LCopy.Free; LForm.Free; LClient.Free;
  end;
end;

end.
