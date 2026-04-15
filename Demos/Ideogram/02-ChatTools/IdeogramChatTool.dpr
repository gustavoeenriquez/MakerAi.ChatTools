program IdeogramChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Ideogram;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiIdeogramImageTool;
  Resp: String;
begin
  Tool := TAiIdeogramImageTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey      := '@IDEOGRAM_API_KEY';
    Tool.Model       := 'V_2';
    Tool.StyleType   := 'DESIGN';
    Tool.AspectRatio := 'ASPECT_16_9';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenImage]';
    Conn.ImageTool := Tool;
    Conn.SystemPrompt.Text :=
      'Genera prompts de diseno grafico en ingles para Ideogram. ' +
      'Especifica estilo, colores, composicion y cualquier texto que deba aparecer.';

    Writeln('Solicitud: Crea un banner para un evento de tecnologia llamado DevSummit 2026');
    Writeln('Procesando...');
    Resp := Conn.AddMessageAndRun(
      'Crea un banner para un evento de tecnologia llamado DevSummit 2026', 'user', []);
    Writeln('Descripción: ', Resp);
  finally
    Conn.ImageTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Ideogram via ChatTools Demo            ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
