program GeminiSpeechDirect;

// Demo 01 - Gemini TTS + STT directo
// TTS: response es base64 PCM en JSON (no binario directo como OpenAI)
// STT: audio como inlineData base64 en el body JSON (no multipart)
// REQUISITO: GEMINI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.GeminiSpeech;

const
  AUDIO_FILE   = 'C:\test_audio.mp3';
  OUTPUT_AUDIO = 'gemini_tts.pcm';

procedure RunTTS;
var
  Tool  : TAiGeminiSpeechTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Gemini TTS (gemini-2.5-flash-preview-tts / voz Puck) ---');
  Tool   := TAiGeminiSpeechTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey    := '@GEMINI_API_KEY';
    Tool.TTSModel  := 'gemini-2.5-flash-preview-tts';
    Tool.VoiceName := 'Puck';

    AskMsg.Prompt := 'Welcome to Gemini TTS. I can speak with natural sounding voices.';
    Write('Generando audio (respuesta: base64 PCM 24kHz)... ');
    Tool.ExecuteSpeechGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile(OUTPUT_AUDIO);
      Writeln('OK -> ' + OUTPUT_AUDIO +
              ' (' + IntToStr(ResMsg.MediaFiles[0].Stream.Size) + ' bytes)');
      Writeln('Nota: PCM 24kHz mono 16-bit. Usar ffmpeg para convertir a WAV/MP3.');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunSTT;
var
  Tool  : TAiGeminiSpeechTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Gemini STT (gemini-2.5-flash) ---');
  if not FileExists(AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ' + AUDIO_FILE + ' no encontrado.'); Exit;
  end;
  Tool   := TAiGeminiSpeechTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@GEMINI_API_KEY';
    Tool.STTModel := 'gemini-2.5-flash';
    Media.LoadFromFile(AUDIO_FILE);
    Write('Transcribiendo (audio como inlineData base64)... ');
    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln(ResMsg.Prompt);
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Gemini Speech Direct Demo (TTS+STT)  ');
    Writeln('======================================');
    Writeln;
    RunTTS;
    Writeln;
    Writeln('======================================');
    Writeln;
    RunSTT;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
