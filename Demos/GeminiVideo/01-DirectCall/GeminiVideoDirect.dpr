program GeminiVideoDirect;

// Demo 01 - Gemini Veo directo (Long Running Operation)
// Submit: POST :predictLongRunning -> operation name
// Poll: GET /operations/{name} hasta done=true
// Resultado: URI del video (requiere x-goog-api-key para descargar)
// REQUISITO: GEMINI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.GeminiVideo;

procedure RunVeo2;
var
  Tool  : TAiGeminiVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Gemini Veo 2.0 (8 seg, 16:9, 720p) ---');
  Tool   := TAiGeminiVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey          := '@GEMINI_API_KEY';
    Tool.Model           := 'veo-2.0-generate-001';
    Tool.AspectRatio     := '16:9';
    Tool.Resolution      := '720p';
    Tool.DurationSeconds := 8;
    Tool.PersonGeneration := 'allow_all';

    AskMsg.Prompt :=
      'A majestic waterfall in a tropical rainforest, slow motion, ' +
      'golden sunlight filtering through the mist, 4K cinematic';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (LRO polling, puede tardar 1-5 minutos)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Video URI: ', ResMsg.Prompt);
      Writeln;
      Writeln('Para descargar el video:');
      Writeln('  GET ' + ResMsg.Prompt);
      Writeln('  Header: x-goog-api-key: {GEMINI_API_KEY}');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Gemini Veo Direct Demo               ');
    Writeln('======================================');
    Writeln;
    RunVeo2;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
