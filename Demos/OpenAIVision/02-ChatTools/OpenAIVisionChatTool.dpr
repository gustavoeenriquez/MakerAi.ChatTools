program OpenAIVisionChatTool;

// Demo 02 - OpenAI Vision via bridge cap_Image en TAiChatConnection
// Gap=[cap_Image]: InternalRunImageDescription -> VisionTool.ExecuteImageDescription
// La descripción se inyecta como contexto antes de que el LLM responda.
// REQUISITO: OPENAI_API_KEY + TEST_IMAGE_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.OpenAIVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiOpenAIVisionTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool  := TAiOpenAIVisionTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey  := '@OPENAI_API_KEY';
    Tool.Model   := 'gpt-4o-mini';
    Tool.Detail  := 'auto';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_Image]: el bridge llama VisionTool antes de enviar al LLM
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Image]';
    Conn.VisionTool := Tool;
    Conn.SystemPrompt.Text :=
      'Analiza la descripción de la imagen provista y responde la pregunta del usuario.';

    Media.LoadFromFile(TEST_IMAGE);

    Writeln('Imagen  : ', TEST_IMAGE);
    Writeln('Pregunta: Que ves en esta imagen? Describe los elementos principales.');
    Writeln('Procesando (OpenAI Vision describe + GPT responde)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Que ves en esta imagen? Describe los elementos principales.',
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
    Writeln(' OpenAI Vision via ChatTools Demo     ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
