program RunwayMLChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.RunwayML;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiRunwayMLVideoTool;
  Resp: String;
begin
  Tool := TAiRunwayMLVideoTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey   := '@RUNWAYML_API_KEY';
    Tool.Model    := 'gen4_turbo';
    Tool.Duration := 5;
    Tool.Ratio    := '1280:720';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_GenVideo]: Runway genera el video
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenVideo]';
    Conn.VideoTool := Tool;
    Conn.SystemPrompt.Text :=
      'Cuando el usuario pida un video, crea un prompt cinematico detallado en ingles ' +
      'para Runway Gen-4, describiendo escena, movimiento de camara, iluminacion y atmósfera.';

    Writeln('Solicitud: Crea un video de un atardecer sobre el oceano con olas suaves');
    Writeln('Procesando (Claude genera prompt + Runway genera video)...');
    Resp := Conn.AddMessageAndRun(
      'Crea un video de un atardecer sobre el oceano con olas suaves', 'user', []);
    Writeln('Descripción/URL: ', Resp);
  finally
    Conn.VideoTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Runway ML via ChatTools Demo           ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
