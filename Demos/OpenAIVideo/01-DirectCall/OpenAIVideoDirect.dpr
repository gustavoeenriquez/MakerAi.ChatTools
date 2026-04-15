program OpenAIVideoDirect;

// Demo 01 - OpenAI Sora directo
// Submit: POST /v1/videos (multipart form-data) -> job id
// Poll: GET /v1/videos/{id} hasta status='completed'
// Descarga: GET /v1/videos/{id}/content (requiere Bearer auth)
// REQUISITO: OPENAI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.OpenAIVideo;

procedure RunSora;
var
  Tool  : TAiOpenAIVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- OpenAI Sora (5 seg, 1280x720) ---');
  Tool   := TAiOpenAIVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey  := '@OPENAI_API_KEY';
    Tool.Model   := 'sora';
    Tool.Seconds := 5;
    Tool.Size    := '1280x720';

    AskMsg.Prompt :=
      'A lone wolf standing on a snowy mountain peak at night, ' +
      'full moon, Northern lights in the sky, cinematic, 4K';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (multipart submit + polling ~1-5 minutos)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Download URL: ', ResMsg.Prompt);
      Writeln;
      Writeln('Para descargar el video:');
      Writeln('  GET ' + ResMsg.Prompt);
      Writeln('  Header: Authorization: Bearer {OPENAI_API_KEY}');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' OpenAI Sora Direct Demo              ');
    Writeln('======================================');
    Writeln;
    RunSora;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
