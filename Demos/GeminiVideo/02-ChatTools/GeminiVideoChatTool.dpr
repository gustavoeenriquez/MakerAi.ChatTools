program GeminiVideoChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.GeminiVideo;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiGeminiVideoTool;
  Resp: String;
begin
  Tool := TAiGeminiVideoTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey      := '@GEMINI_API_KEY';
    Tool.Model       := 'veo-2.0-generate-001';
    Tool.AspectRatio := '16:9';
    Tool.Resolution  := '720p';

    Conn.DriverName := 'Gemini';
    Conn.Model      := 'gemini-2.5-flash';
    Conn.Params.Values['ApiKey']       := '@GEMINI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenVideo]';
    Conn.VideoTool := Tool;
    Conn.SystemPrompt.Text :=
      'Crea prompts cinematicos en ingles para Veo. ' +
      'Describe escena, movimiento de camara, iluminacion, colores y atmósfera.';

    Writeln('Solicitud: Crea un video de un amanecer sobre el mar');
    Writeln('Procesando (Gemini genera prompt + Veo genera video ~1-5 min)...');
    Resp := Conn.AddMessageAndRun(
      'Crea un video de un amanecer sobre el mar', 'user', []);
    Writeln('Descripcion/URI: ', Resp);
  finally
    Conn.VideoTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Gemini Veo via ChatTools Demo        ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
