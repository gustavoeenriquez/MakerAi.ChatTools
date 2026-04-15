program OpenAISpeechDirect;

// Demo 01 - OpenAI TTS + STT directo (sin TAiChatConnection)
// TTS: POST /v1/audio/speech -> binario MP3
// STT: POST /v1/audio/transcriptions (multipart Whisper) -> texto
// REQUISITO: OPENAI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.OpenAISpeech;

const
  AUDIO_FILE   = 'C:\test_audio.mp3';
  OUTPUT_AUDIO = 'openai_tts.mp3';

procedure RunTTS;
var
  Tool  : TAiOpenAISpeechTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- OpenAI TTS (tts-1 / alloy) ---');
  Tool   := TAiOpenAISpeechTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey         := '@OPENAI_API_KEY';
    Tool.TTSModel       := 'tts-1';
    Tool.Voice          := 'alloy';
    Tool.ResponseFormat := 'mp3';

    AskMsg.Prompt := 'Hola, soy un asistente de inteligencia artificial creado por OpenAI.';
    Write('Generando audio... ');
    Tool.ExecuteSpeechGeneration(AskMsg.Prompt, ResMsg, AskMsg);
    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile(OUTPUT_AUDIO);
      Writeln('OK -> ' + OUTPUT_AUDIO);
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunSTT;
var
  Tool  : TAiOpenAISpeechTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- OpenAI STT (Whisper-1) ---');
  if not FileExists(AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ' + AUDIO_FILE + ' no encontrado.'); Exit;
  end;
  Tool   := TAiOpenAISpeechTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@OPENAI_API_KEY';
    Tool.STTModel := 'whisper-1';
    Tool.Language := 'es';
    Media.LoadFromFile(AUDIO_FILE);
    Write('Transcribiendo... ');
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
    Writeln(' OpenAI Speech Direct Demo (TTS+STT)  ');
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
