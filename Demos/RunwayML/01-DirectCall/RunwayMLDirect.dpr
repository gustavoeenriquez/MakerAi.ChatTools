program RunwayMLDirect;

// Demo 01 - Llamado directo a TAiRunwayMLVideoTool
// Runway Gen-4 Turbo: generación de video cinematico desde texto.
// CRITICO: requiere header X-Runway-Version: 2024-11-06 (incluido en GetApiHeaders)
// REQUISITO: RUNWAYML_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.RunwayML;

procedure RunGen4;
var
  Tool  : TAiRunwayMLVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Runway Gen-4 Turbo (5 segundos) ---');
  Tool   := TAiRunwayMLVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey   := '@RUNWAYML_API_KEY';
    Tool.Model    := 'gen4_turbo';
    Tool.Duration := 5;
    Tool.Ratio    := '1280:720';

    AskMsg.Prompt :=
      'A lone astronaut walking on the surface of Mars, red dusty terrain, ' +
      'distant mountains, dramatic sky, cinematic slow motion, 4K';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (submit + polling ~30-90 seg)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Video generado!');
      Writeln('URL: ', ResMsg.Prompt);
    end
    else
      Writeln('No se genero video');
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunGen4Vertical;
var
  Tool  : TAiRunwayMLVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Runway Gen-4 Turbo (vertical 9:16, 10 seg) ---');
  Tool   := TAiRunwayMLVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey         := '@RUNWAYML_API_KEY';
    Tool.Model          := 'gen4_turbo';
    Tool.Duration       := 10;
    Tool.Ratio          := '720:1280';  // Vertical para redes sociales
    Tool.NegativePrompt := 'blurry, low quality, distorted faces';

    AskMsg.Prompt :=
      'Cherry blossom petals falling in slow motion, Japanese garden, ' +
      'soft pink light, peaceful atmosphere';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (10 seg, formato vertical)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Video URL: ', ResMsg.Prompt);
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Runway ML Direct Demo                  ');
    Writeln('========================================');
    Writeln;
    RunGen4;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunGen4Vertical;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
