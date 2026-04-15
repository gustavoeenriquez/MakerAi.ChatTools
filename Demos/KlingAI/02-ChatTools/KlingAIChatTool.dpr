program KlingAIChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.KlingAI;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiKlingAIVideoTool;
  Resp: String;
begin
  Tool := TAiKlingAIVideoTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey      := '@KLINGAI_API_KEY';
    Tool.ApiSecret   := '@KLINGAI_API_SECRET';
    Tool.Model       := 'kling-v2';
    Tool.Duration    := '5';
    Tool.AspectRatio := '16:9';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenVideo]';
    Conn.VideoTool := Tool;
    Conn.SystemPrompt.Text :=
      'Genera prompts cinematicos en ingles para Kling AI video generation. ' +
      'Describe con detalle: escena, movimientos, iluminacion, estilo visual y atmósfera.';

    Writeln('Solicitud: Crea un video de una ciudad futurista en la noche');
    Writeln('Procesando (Claude + Kling AI JWT)...');
    Resp := Conn.AddMessageAndRun(
      'Crea un video de una ciudad futurista en la noche', 'user', []);
    Writeln('Descripción/URL: ', Resp);
  finally
    Conn.VideoTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Kling AI via ChatTools Demo            ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
