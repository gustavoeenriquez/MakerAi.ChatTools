program GeminiVisionChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.GeminiVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiGeminiVisionTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool  := TAiGeminiVisionTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@GEMINI_API_KEY';
    Tool.Model  := 'gemini-2.5-flash';

    Conn.DriverName := 'Gemini';
    Conn.Model      := 'gemini-2.5-flash';
    Conn.Params.Values['ApiKey']       := '@GEMINI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Image]';
    Conn.VisionTool := Tool;
    Conn.SystemPrompt.Text :=
      'Usando la descripción de la imagen disponible, responde las preguntas del usuario.';

    Media.LoadFromFile(TEST_IMAGE);

    Writeln('Imagen  : ', TEST_IMAGE);
    Writeln('Pregunta: Que emociones transmite esta imagen?');
    Writeln('Procesando (Gemini Vision + Gemini LLM)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Que emociones transmite esta imagen?', 'user', [Media]);

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
    Writeln(' Gemini Vision via ChatTools Demo     ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
