program OpenAIVideoChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.OpenAIVideo;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiOpenAIVideoTool;
  Resp: String;
begin
  Tool := TAiOpenAIVideoTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey  := '@OPENAI_API_KEY';
    Tool.Model   := 'sora';
    Tool.Seconds := 5;
    Tool.Size    := '1280x720';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenVideo]';
    Conn.VideoTool := Tool;
    Conn.SystemPrompt.Text :=
      'Genera un prompt cinematico en ingles para Sora. ' +
      'Incluye: sujeto, accion, escena, movimiento de camara e iluminacion.';

    Writeln('Solicitud: Crea un video de un astronauta en la luna');
    Writeln('Procesando (GPT genera prompt + Sora genera video ~1-5 min)...');
    Resp := Conn.AddMessageAndRun(
      'Crea un video de un astronauta en la luna', 'user', []);
    Writeln('Descripcion/URL: ', Resp);
  finally
    Conn.VideoTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' OpenAI Sora via ChatTools Demo       ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
