program StabilityAIChatTool;

// Demo 02 - Stability AI via bridge cap_GenImage
// REQUISITO: STABILITY_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.StabilityAI;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiStabilityAIImageTool;
  Resp: String;
begin
  Tool := TAiStabilityAIImageTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey      := '@STABILITY_API_KEY';
    Tool.Model       := 'sd3.5-large';
    Tool.AspectRatio := '1:1';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenImage]';
    Conn.ImageTool := Tool;
    Conn.SystemPrompt.Text :=
      'Cuando el usuario pida una imagen, genera un prompt fotografico ' +
      'detallado en ingles para Stable Diffusion.';

    Writeln('Solicitud: Crea una imagen de un cafe acogedor en Paris');
    Writeln('Procesando (GPT + Stability AI SD3.5)...');
    Resp := Conn.AddMessageAndRun(
      'Crea una imagen de un cafe acogedor en Paris', 'user', []);
    Writeln('Descripción: ', Resp);
  finally
    Conn.ImageTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Stability AI via ChatTools Demo        ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
