program StabilityAIDirect;

// Demo 01 - Llamado directo a TAiStabilityAIImageTool
// Stability AI: multipart/form-data -> imagen binaria directa (sin polling).
// REQUISITO: STABILITY_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.StabilityAI;

procedure RunSD35;
var
  Tool  : TAiStabilityAIImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- SD 3.5 Large (alta calidad) ---');
  Tool   := TAiStabilityAIImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey       := '@STABILITY_API_KEY';
    Tool.Model        := 'sd3.5-large';
    Tool.AspectRatio  := '16:9';
    Tool.OutputFormat := 'png';

    AskMsg.Prompt := 'A serene Japanese garden with cherry blossoms, ' +
                     'koi pond, wooden bridge, golden hour lighting, 8K';

    Writeln('Prompt: ', AskMsg.Prompt);
    Write('Generando (síncrono, ~10-20 seg)... ');
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('stability_sd35.png');
      Writeln('OK -> stability_sd35.png');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunSD35Turbo;
var
  Tool  : TAiStabilityAIImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- SD 3.5 Turbo (rápido) ---');
  Tool   := TAiStabilityAIImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey          := '@STABILITY_API_KEY';
    Tool.Model           := 'sd3-turbo';
    Tool.AspectRatio     := '1:1';
    Tool.OutputFormat    := 'jpeg';
    Tool.NegativePrompt  := 'blurry, low quality, distorted';

    AskMsg.Prompt := 'Portrait of a wise elderly wizard with a long white beard, ' +
                     'wearing blue robes, soft lighting, detailed face';

    Writeln('Prompt: ', AskMsg.Prompt);
    Write('Generando (turbo, ~5-10 seg)... ');
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('stability_turbo.jpg');
      Writeln('OK -> stability_turbo.jpg');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Stability AI Direct Demo               ');
    Writeln('========================================');
    Writeln;
    RunSD35;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunSD35Turbo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
