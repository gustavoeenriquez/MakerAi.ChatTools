program ClaudeSpeechChatTool;

// Demo 02 - Claude STT via bridge cap_Audio en TAiChatConnection
// Flujo: audio adjunto → Claude transcribe → Claude LLM responde sobre el contenido
// REQUISITO: CLAUDE_API_KEY + AUDIO_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.ClaudeSpeech;

const
  AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiClaudeSTTTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ' + AUDIO_FILE + ' no encontrado.'); Exit;
  end;

  Tool  := TAiClaudeSTTTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@CLAUDE_API_KEY';
    Tool.Model  := 'claude-opus-4-6';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_Audio]: Claude transcribe el audio antes de enviarlo al LLM
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Audio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Se te proporcionara la transcripción de un audio. ' +
      'Analiza su contenido y responde de forma clara y concisa.';

    Media.LoadFromFile(AUDIO_FILE);

    Writeln('Audio   : ', AUDIO_FILE);
    Writeln('Pregunta: Resume el contenido del audio');
    Writeln('Procesando (Claude opus STT + Claude haiku LLM)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Resume el contenido del audio', 'user', [Media]);
    Writeln('=== Respuesta ===');
    Writeln(Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free; Media.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Claude STT via ChatTools Demo        ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
