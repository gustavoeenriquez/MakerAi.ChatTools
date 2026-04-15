program FalAiDirect;

// Demo 01 - Llamado directo a TAiFalAiImageTool
// fal.ai: FLUX Schnell rápido (4 pasos, ~5 segundos)
// REQUISITO: FAL_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.FalAi;

const OUTPUT_IMG = 'falai_output.jpg';

procedure RunFluxSchnell;
var
  Tool  : TAiFalAiImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- FLUX Schnell (rápido, 4 pasos) ---');
  Tool   := TAiFalAiImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey            := '@FAL_API_KEY';
    Tool.ModelPath         := 'fal-ai/flux/schnell';
    Tool.ImageSize         := 'square_hd';
    Tool.NumInferenceSteps := 4;
    Tool.OutputFormat      := 'jpeg';

    AskMsg.Prompt := 'A majestic mountain landscape at golden hour, ' +
                     'photorealistic, 4K quality, dramatic lighting';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (paso 1: submit, paso 2: polling, paso 3: descarga)...');
    Writeln;
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile(OUTPUT_IMG);
      Writeln('Imagen guardada en: ', OUTPUT_IMG);
    end
    else
      Writeln('No se genero imagen');
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunFluxPro;
var
  Tool  : TAiFalAiImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- FLUX Pro v1.1 (alta calidad, mas lento) ---');
  Tool   := TAiFalAiImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey            := '@FAL_API_KEY';
    Tool.ModelPath         := 'fal-ai/flux-pro/v1.1';
    Tool.ImageSize         := 'landscape_16_9';
    Tool.NumInferenceSteps := 28;
    Tool.GuidanceScale     := 3.5;
    Tool.OutputFormat      := 'jpeg';

    AskMsg.Prompt := 'Futuristic city skyline at night with neon lights, ' +
                     'cinematic style, ultra detailed';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (puede tardar 20-40 segundos)...');
    Writeln;
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('falai_pro_output.jpg');
      Writeln('Imagen guardada en: falai_pro_output.jpg');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' fal.ai Image Generation Direct Demo    ');
    Writeln('========================================');
    Writeln;
    RunFluxSchnell;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunFluxPro;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
