program ClaudeSpeechDirect;

// Demo 01 - Claude STT directo
// Claude solo hace STT (no tiene TTS nativo).
// El audio se envia como 'document' base64 en el messages API.
// REQUISITO: CLAUDE_API_KEY + TEST_AUDIO_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.ClaudeSpeech;

const
  AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunSTT;
var
  Tool  : TAiClaudeSTTTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Claude STT (claude-opus-4-6) ---');
  if not FileExists(AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ' + AUDIO_FILE + ' no encontrado.'); Exit;
  end;
  Tool   := TAiClaudeSTTTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@CLAUDE_API_KEY';
    Tool.Model    := 'claude-opus-4-6';
    Tool.MaxTokens := 4096;
    Tool.TranscribePrompt :=
      'Please transcribe this audio file accurately and completely. ' +
      'Return only the transcription, no additional commentary.';

    Media.LoadFromFile(AUDIO_FILE);

    Writeln('Archivo: ', AUDIO_FILE);
    Write('Transcribiendo con Claude (audio como base64 document)... ');
    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln('=== Transcripción ===');
    Writeln(ResMsg.Prompt);
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Claude STT Direct Demo               ');
    Writeln('======================================');
    Writeln;
    RunSTT;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
