program ElevenLabsDirect;

// Demo 01 - Llamado directo a TAiElevenLabsTool (TTS + STT)
// Muestra generación de voz y transcripción sin TAiChatConnection.
// REQUISITO: variable de entorno ELEVENLABS_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.ElevenLabs;

const
  OUTPUT_AUDIO  = 'elevenlabs_output.mp3';
  TEST_AUDIO    = 'C:\test_audio.mp3';  // para STT

procedure RunTTS;
var
  Tool  : TAiElevenLabsTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- TTS: texto a voz ---');
  Tool   := TAiElevenLabsTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey           := '@ELEVENLABS_API_KEY';
    Tool.VoiceId          := 'JBFqnCBsd6RMkjVDRZzb';  // George
    Tool.TTSModel         := 'eleven_multilingual_v2';
    Tool.Stability        := 0.5;
    Tool.SimilarityBoost  := 0.8;
    Tool.OutputFormat     := 'mp3_44100_128';

    AskMsg.Prompt := 'Hola, soy un asistente de inteligencia artificial. ' +
                     'Puedo ayudarte a responder preguntas y realizar tareas.';

    Writeln('Texto: ', AskMsg.Prompt);
    Write('Generando audio... ');
    Tool.ExecuteSpeechGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile(OUTPUT_AUDIO);
      Writeln('OK');
      Writeln('Audio guardado en: ', OUTPUT_AUDIO);
    end
    else
      Writeln('ERROR: no se genero audio');
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunSTT;
var
  Tool  : TAiElevenLabsTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- STT: voz a texto (Scribe) ---');
  if not FileExists(TEST_AUDIO) then
  begin
    Writeln('OMITIDO: ', TEST_AUDIO, ' no encontrado.');
    Exit;
  end;
  Tool   := TAiElevenLabsTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey      := '@ELEVENLABS_API_KEY';
    Tool.STTModel    := 'scribe_v1';
    Tool.STTLanguage := 'es';
    Media.LoadFromFile(TEST_AUDIO);
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
    Writeln('========================================');
    Writeln(' ElevenLabs Direct Demo (TTS + STT)    ');
    Writeln('========================================');
    Writeln;
    RunTTS;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunSTT;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
