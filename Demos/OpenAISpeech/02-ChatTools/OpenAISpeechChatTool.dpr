program OpenAISpeechChatTool;

// Demo 02 - OpenAI TTS via bridge cap_GenAudio en TAiChatConnection
// REQUISITO: OPENAI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.OpenAISpeech;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiOpenAISpeechTool;
  Resp: String;
begin
  Tool := TAiOpenAISpeechTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey         := '@OPENAI_API_KEY';
    Tool.TTSModel       := 'tts-1';
    Tool.Voice          := 'nova';
    Tool.ResponseFormat := 'mp3';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenAudio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde brevemente en español. El texto sera convertido a audio, ' +
      'usa lenguaje natural sin listas ni markdown.';

    Writeln('Pregunta: Que es la inteligencia artificial?');
    Writeln('Procesando (GPT genera respuesta + OpenAI TTS convierte a audio)...');
    Resp := Conn.AddMessageAndRun(
      'Que es la inteligencia artificial?', 'user', []);
    Writeln('Texto: ', Resp);
    Writeln('(El audio esta en ResMsg.MediaFiles[0])');
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' OpenAI TTS via ChatTools Demo        ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
