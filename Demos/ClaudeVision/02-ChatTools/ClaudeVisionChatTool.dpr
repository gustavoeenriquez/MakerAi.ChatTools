program ClaudeVisionChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.ClaudeVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiClaudeVisionTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool  := TAiClaudeVisionTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@CLAUDE_API_KEY';
    Tool.Model  := 'claude-haiku-4-5-20251001';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Image]';
    Conn.VisionTool := Tool;
    Conn.SystemPrompt.Text :=
      'Tienes acceso a una descripción detallada de la imagen. ' +
      'Responde las preguntas del usuario basandote en esa descripción.';

    Media.LoadFromFile(TEST_IMAGE);

    Writeln('Imagen  : ', TEST_IMAGE);
    Writeln('Pregunta: Si tuvieras que usar esta imagen en una presentacion, que titulo le pondrias?');
    Writeln('Procesando (Claude Vision + Claude LLM)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Si tuvieras que usar esta imagen en una presentacion, que titulo le pondrias?',
      'user', [Media]);

    Writeln('=== Respuesta ===');
    Writeln(Resp);
  finally
    Conn.VisionTool := nil;
    Conn.Free; Tool.Free; Media.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Claude Vision via ChatTools Demo     ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
