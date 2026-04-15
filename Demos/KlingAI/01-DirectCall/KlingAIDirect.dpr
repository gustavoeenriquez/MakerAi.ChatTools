program KlingAIDirect;

// Demo 01 - Llamado directo a TAiKlingAIVideoTool
// Kling AI: autenticación JWT con firma HMAC-SHA256.
// Cada llamada genera un nuevo JWT — los tokens expiran a los 30 min.
// REQUISITO: KLINGAI_API_KEY + KLINGAI_API_SECRET

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.KlingAI;

procedure RunKlingV2;
var
  Tool  : TAiKlingAIVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Kling v2 (5 seg, 16:9) ---');
  Tool   := TAiKlingAIVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey      := '@KLINGAI_API_KEY';
    Tool.ApiSecret   := '@KLINGAI_API_SECRET';
    Tool.Model       := 'kling-v2';
    Tool.Duration    := '5';
    Tool.AspectRatio := '16:9';
    Tool.Mode        := 'std';
    Tool.CfgScale    := 0.5;

    AskMsg.Prompt :=
      'A majestic dragon soaring through storm clouds, ' +
      'lightning flashing, dark fantasy atmosphere, cinematic';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Procesando (JWT auth + submit + polling ~30-120 seg)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Video generado!');
      Writeln('URL: ', ResMsg.Prompt);
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunKlingV2Pro;
var
  Tool  : TAiKlingAIVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Kling v2 modo pro (10 seg, alta calidad) ---');
  Tool   := TAiKlingAIVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey         := '@KLINGAI_API_KEY';
    Tool.ApiSecret      := '@KLINGAI_API_SECRET';
    Tool.Model          := 'kling-v2';
    Tool.Duration       := '10';
    Tool.AspectRatio    := '1:1';
    Tool.Mode           := 'pro';  // Alta calidad — mas lento y costoso
    Tool.NegativePrompt := 'blurry, distorted, low quality';

    AskMsg.Prompt :=
      'Time lapse of flowers blooming in a forest, morning dew, ' +
      'golden hour light, macro photography, ultra detailed';

    Writeln('Prompt: ', AskMsg.Prompt);
    Writeln('Modo: pro (10 seg, puede tardar mas)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
      Writeln('Video URL: ', ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Kling AI Direct Demo (JWT Auth)        ');
    Writeln('========================================');
    Writeln;
    RunKlingV2;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunKlingV2Pro;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
