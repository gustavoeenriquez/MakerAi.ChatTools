program ReplicateDirect;

// Demo 01 - Llamado directo a TAiReplicateImageTool
// Replicate: acceso a FLUX, SDXL y cientos de modelos open-source.
// REQUISITO: REPLICATE_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Replicate;

procedure RunFluxSchnell;
var
  Tool  : TAiReplicateImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- FLUX Schnell via Replicate ---');
  Tool   := TAiReplicateImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey            := '@REPLICATE_API_KEY';
    Tool.ModelVersion      := 'black-forest-labs/flux-schnell';
    Tool.ImageWidth        := 1024;
    Tool.ImageHeight       := 1024;
    Tool.NumInferenceSteps := 4;
    Tool.GoFast            := True;
    Tool.OutputFormat      := 'webp';
    Tool.OutputQuality     := 90;

    AskMsg.Prompt := 'An astronaut riding a horse on Mars, ' +
                     'concept art, vibrant colors, detailed';

    Writeln('Modelo: ', Tool.ModelVersion);
    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (submit + polling + descarga)...');
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('replicate_flux.webp');
      Writeln('Imagen guardada: replicate_flux.webp');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Replicate Direct Demo                  ');
    Writeln('========================================');
    Writeln;
    RunFluxSchnell;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
