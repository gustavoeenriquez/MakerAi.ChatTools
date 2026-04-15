program FalAiChatTool;

// Demo 02 - fal.ai integrado como ImageTool via bridge cap_GenImage
// El LLM genera el prompt de imagen y fal.ai lo convierte en imagen.
// REQUISITO: FAL_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.FalAi;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiFalAiImageTool;
  Resp: String;
begin
  Tool := TAiFalAiImageTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey            := '@FAL_API_KEY';
    Tool.ModelPath         := 'fal-ai/flux/schnell';
    Tool.ImageSize         := 'square_hd';
    Tool.NumInferenceSteps := 4;
    Tool.OutputFormat      := 'jpeg';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_GenImage]: el bridge genera la imagen con fal.ai
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenImage]';
    Conn.ImageTool := Tool;
    Conn.SystemPrompt.Text :=
      'Cuando el usuario pida generar una imagen, crea un prompt detallado ' +
      'en ingles para generación de imagen con IA, enfocado en calidad fotografica.';

    Writeln('Solicitud: Genera una imagen de un paisaje tropical al atardecer');
    Writeln('Procesando (Claude genera prompt + fal.ai genera imagen)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Genera una imagen de un paisaje tropical al atardecer', 'user', []);
    Writeln('Descripción: ', Resp);
    Writeln;
    Writeln('Nota: la imagen generada esta en ResMsg.MediaFiles[0].');
    Writeln('Para obtenerla, usar el evento OnReceiveDataEnd y acceder al ResMsg.');
  finally
    Conn.ImageTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' fal.ai via ChatTools Demo              ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
