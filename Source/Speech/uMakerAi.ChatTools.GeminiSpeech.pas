unit uMakerAi.ChatTools.GeminiSpeech;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiGeminiSpeechTool
// Implementacion de IAiSpeechTool usando las APIs nativas de Google Gemini.
//
// ExecuteSpeechGeneration → TTS via generateContent con responseModalities=AUDIO
//   Modelos TTS: 'gemini-2.5-flash-preview-tts', 'gemini-2.5-pro-preview-tts'
//   Voces: Puck, Charon, Kore, Fenrir, Aoede, Leda, Orus, Zephyr (y mas)
//   Response: inlineData.data en base64 (PCM 24kHz mono 16-bit)
//
// ExecuteTranscription → STT via generateContent con audio como inlineData
//   Modelos STT: 'gemini-2.5-flash', 'gemini-2.0-flash'
//   Request: audio como base64 en inlineData + prompt de transcripción
//   Response: candidates[0].content.parts[0].text
//
// AUTENTICACION: query param ?key={apikey} — NO usa Authorization header
//
// Env var requerida: GEMINI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiGeminiSpeechTool = class(TAiSpeechToolBase)
  private
    FApiKey    : String;
    FTTSModel  : String;
    FVoiceName : String;
    FSTTModel  : String;
    FSTTPrompt : String;

    function ResolveApiKey: String;
    function GetApiUrl(const AModel: String): String;
    function GetAudioMimeType(const AFileName: String): String;
    function ExtractTextFromResponse(AResponse: TJSONObject): String;
    function ExtractAudioFromResponse(AResponse: TJSONObject;
             out AMimeType: String): TBytes;
  protected
    procedure ExecuteSpeechGeneration(const AText: String;
                                      ResMsg, AskMsg: TAiChatMessage); override;
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Gemini. Soporta '@ENV_VAR' (default '@GEMINI_API_KEY')
    // AUTENTICACION: query param ?key= (no header Authorization)
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo TTS: 'gemini-2.5-flash-preview-tts', 'gemini-2.5-pro-preview-tts'
    // (default 'gemini-2.5-flash-preview-tts')
    property TTSModel: String read FTTSModel write FTTSModel;
    // Nombre de voz para TTS (default 'Puck')
    // Opciones: Puck, Charon, Kore, Fenrir, Aoede, Leda, Orus, Zephyr, etc.
    property VoiceName: String read FVoiceName write FVoiceName;
    // Modelo para STT: 'gemini-2.5-flash', 'gemini-2.0-flash' (default 'gemini-2.5-flash')
    property STTModel: String read FSTTModel write FSTTModel;
    // Prompt de instruccion para la transcripción (default en español)
    property STTPrompt: String read FSTTPrompt write FSTTPrompt;
  end;

const
  GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models/';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiGeminiSpeechTool]);
end;

constructor TAiGeminiSpeechTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey    := '@GEMINI_API_KEY';
  FTTSModel  := 'gemini-2.5-flash-preview-tts';
  FVoiceName := 'Puck';
  FSTTModel  := 'gemini-2.5-flash';
  FSTTPrompt := 'Transcribe este audio con precision. Devuelve solo la transcripción.';
end;

function TAiGeminiSpeechTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiGeminiSpeechTool.GetApiUrl(const AModel: String): String;
begin
  Result := GEMINI_BASE_URL + AModel + ':generateContent?key=' + ResolveApiKey;
end;

function TAiGeminiSpeechTool.GetAudioMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      Ext = '.mp3'  then Result := 'audio/mp3'
  else if Ext = '.wav'  then Result := 'audio/wav'
  else if Ext = '.m4a'  then Result := 'audio/m4a'
  else if Ext = '.ogg'  then Result := 'audio/ogg'
  else if Ext = '.flac' then Result := 'audio/flac'
  else if Ext = '.aac'  then Result := 'audio/aac'
  else                       Result := 'audio/mp3';
end;

// ---------------------------------------------------------------------------
// Extrae el texto de la respuesta de Gemini: candidates[0].content.parts[0].text
// ---------------------------------------------------------------------------
function TAiGeminiSpeechTool.ExtractTextFromResponse(AResponse: TJSONObject): String;
var
  JCandidates: TJSONArray;
  JCandidate : TJSONObject;
  JContent   : TJSONObject;
  JParts     : TJSONArray;
  JPart      : TJSONObject;
begin
  Result := '';
  if not AResponse.TryGetValue<TJSONArray>('candidates', JCandidates) or
     (JCandidates.Count = 0) then Exit;

  JCandidate := TJSONObject(JCandidates.Items[0]);
  if not JCandidate.TryGetValue<TJSONObject>('content', JContent) then Exit;
  if not JContent.TryGetValue<TJSONArray>('parts', JParts) or (JParts.Count = 0) then Exit;

  JPart := TJSONObject(JParts.Items[0]);
  JPart.TryGetValue<String>('text', Result);
end;

// ---------------------------------------------------------------------------
// Extrae el audio base64 de la respuesta TTS de Gemini.
// candidates[0].content.parts[0].inlineData.{mimeType, data}
// ---------------------------------------------------------------------------
function TAiGeminiSpeechTool.ExtractAudioFromResponse(AResponse: TJSONObject;
  out AMimeType: String): TBytes;
var
  JCandidates: TJSONArray;
  JCandidate : TJSONObject;
  JContent   : TJSONObject;
  JParts     : TJSONArray;
  JPart      : TJSONObject;
  JInlineData: TJSONObject;
  LBase64    : String;
begin
  SetLength(Result, 0);
  AMimeType := 'audio/pcm';

  if not AResponse.TryGetValue<TJSONArray>('candidates', JCandidates) or
     (JCandidates.Count = 0) then Exit;

  JCandidate := TJSONObject(JCandidates.Items[0]);
  if not JCandidate.TryGetValue<TJSONObject>('content', JContent) then Exit;
  if not JContent.TryGetValue<TJSONArray>('parts', JParts) or (JParts.Count = 0) then Exit;

  JPart := TJSONObject(JParts.Items[0]);
  if not JPart.TryGetValue<TJSONObject>('inlineData', JInlineData) then Exit;

  JInlineData.TryGetValue<String>('mimeType', AMimeType);
  if JInlineData.TryGetValue<String>('data', LBase64) then
    Result := TNetEncoding.Base64.DecodeStringToBytes(LBase64);
end;

// ---------------------------------------------------------------------------
// TTS: POST generateContent con responseModalities=AUDIO.
// La respuesta es audio base64 en inlineData (PCM o formato del modelo).
// DIFERENCIA vs OpenAI TTS: la respuesta es base64 en JSON, no binario directo.
// ---------------------------------------------------------------------------
procedure TAiGeminiSpeechTool.ExecuteSpeechGeneration(const AText: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient    : THTTPClient;
  LResponse  : IHTTPResponse;
  LRequest   : TJSONObject;
  LBody      : TStringStream;
  LResult    : TJSONObject;
  LContents  : TJSONArray;
  LContent   : TJSONObject;
  LParts     : TJSONArray;
  LPart      : TJSONObject;
  LGenConfig : TJSONObject;
  LSpeechConf: TJSONObject;
  LVoiceConf : TJSONObject;
  LPrebuilt  : TJSONObject;
  LAudio     : TAiMediaFile;
  LBytes     : TBytes;
  LMimeType  : String;
  LExt       : String;
begin
  if AText.IsEmpty then begin ReportError('Gemini TTS: texto vacío', nil); Exit; end;

  ReportState(acsConnecting, 'Gemini TTS [' + FTTSModel + '/' + FVoiceName + ']: generando...');

  // Construir el body de la solicitud TTS
  LPart := TJSONObject.Create;
  LPart.AddPair('text', AText);

  LParts := TJSONArray.Create;
  LParts.AddElement(LPart);

  LContent := TJSONObject.Create;
  LContent.AddPair('parts', LParts);

  LContents := TJSONArray.Create;
  LContents.AddElement(LContent);

  // Configuracion de voz
  LPrebuilt := TJSONObject.Create;
  LPrebuilt.AddPair('voiceName', FVoiceName);

  LVoiceConf := TJSONObject.Create;
  LVoiceConf.AddPair('prebuiltVoiceConfig', LPrebuilt);

  LSpeechConf := TJSONObject.Create;
  LSpeechConf.AddPair('voiceConfig', LVoiceConf);

  LGenConfig := TJSONObject.Create;
  LGenConfig.AddPair('responseModalities', TJSONArray.Create.Add('AUDIO'));
  LGenConfig.AddPair('speechConfig', LSpeechConf);

  LRequest := TJSONObject.Create;
  LRequest.AddPair('contents',       LContents);
  LRequest.AddPair('generationConfig', LGenConfig);

  LClient := THTTPClient.Create;
  LBody   := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResponse := LClient.Post(GetApiUrl(FTTSModel), LBody, nil, [
        TNetHeader.Create('Content-Type', 'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Gemini TTS error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Gemini TTS: respuesta JSON invalida');
      try
        LBytes := ExtractAudioFromResponse(LResult, LMimeType);
      finally
        LResult.Free;
      end;

      if Length(LBytes) = 0 then
        raise Exception.Create('Gemini TTS: audio vacío en la respuesta');

      // Determinar extension del archivo por el mimeType
      if      LMimeType.Contains('wav')  then LExt := 'wav'
      else if LMimeType.Contains('mp3')  then LExt := 'mp3'
      else if LMimeType.Contains('ogg')  then LExt := 'ogg'
      else                                    LExt := 'pcm';

      LAudio := TAiMediaFile.Create(nil);
      LAudio.FileName := 'speech.' + LExt;
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
// STT: envia el audio como inlineData base64 y pide la transcripción.
// DIFERENCIA vs OpenAI STT: no es multipart — el audio va en el body JSON.
// ---------------------------------------------------------------------------
procedure TAiGeminiSpeechTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LRequest  : TJSONObject;
  LBody     : TStringStream;
  LResult   : TJSONObject;
  LContents : TJSONArray;
  LContent  : TJSONObject;
  LParts    : TJSONArray;
  LTextPart : TJSONObject;
  LAudioPart: TJSONObject;
  JInline   : TJSONObject;
  LBytes    : TBytes;
  LBase64   : String;
  LMimeType : String;
  LText     : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Gemini STT: archivo de audio no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'Gemini STT [' + FSTTModel + ']: transcribiendo...');

  // Codificar el audio en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64   := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  LMimeType := GetAudioMimeType(aMediaFile.FileName);

  // Construir el body: [prompt de texto + audio inlineData]
  LTextPart := TJSONObject.Create;
  LTextPart.AddPair('text', FSTTPrompt);

  JInline := TJSONObject.Create;
  JInline.AddPair('mimeType', LMimeType);
  JInline.AddPair('data',     LBase64);

  LAudioPart := TJSONObject.Create;
  LAudioPart.AddPair('inlineData', JInline);

  LParts := TJSONArray.Create;
  LParts.AddElement(LTextPart);
  LParts.AddElement(LAudioPart);

  LContent := TJSONObject.Create;
  LContent.AddPair('parts', LParts);

  LContents := TJSONArray.Create;
  LContents.AddElement(LContent);

  LRequest := TJSONObject.Create;
  LRequest.AddPair('contents', LContents);

  LClient := THTTPClient.Create;
  LBody   := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResponse := LClient.Post(GetApiUrl(FSTTModel), LBody, nil, [
        TNetHeader.Create('Content-Type', 'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Gemini STT error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Gemini STT: respuesta JSON invalida');
      try
        LText := ExtractTextFromResponse(LResult);
      finally
        LResult.Free;
      end;

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);
    except
      on E: Exception do begin ReportError(E.Message, E); ResMsg.Prompt := ''; end;
    end;
  finally
    LBody.Free; LRequest.Free; LClient.Free;
  end;
end;

end.
