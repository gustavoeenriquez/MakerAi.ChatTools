program IdeogramDirect;

// Demo 01 - Llamado directo a TAiIdeogramImageTool
// Ideogram es especialmente bueno generando texto legible dentro de imagenes.
// REQUISITO: IDEOGRAM_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Ideogram;

procedure RunDesign;
var
  Tool  : TAiIdeogramImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Ideogram V2 con texto incrustado (DESIGN style) ---');
  Tool   := TAiIdeogramImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey            := '@IDEOGRAM_API_KEY';
    Tool.Model             := 'V_2';
    Tool.StyleType         := 'DESIGN';
    Tool.AspectRatio       := 'ASPECT_16_9';
    Tool.MagicPromptOption := 'AUTO';

    // Ideogram es excelente para texto dentro de imagenes
    AskMsg.Prompt := 'A modern tech company logo design with the text "MakerAI" ' +
                     'in bold futuristic font, blue and white color scheme, ' +
                     'minimalist style, clean background';

    Writeln('Prompt: ', AskMsg.Prompt);
    Write('Generando (síncrono + descarga)... ');
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('ideogram_design.jpg');
      Writeln('OK -> ideogram_design.jpg');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunRealistic;
var
  Tool  : TAiIdeogramImageTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Ideogram V3 Realista ---');
  Tool   := TAiIdeogramImageTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey      := '@IDEOGRAM_API_KEY';
    Tool.Model       := 'V_3';
    Tool.StyleType   := 'REALISTIC';
    Tool.AspectRatio := 'ASPECT_1_1';

    AskMsg.Prompt := 'Professional headshot of a confident business woman, ' +
                     '35 years old, natural smile, office background, soft lighting';

    Writeln('Prompt: ', AskMsg.Prompt);
    Write('Generando... ');
    Tool.ExecuteImageGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile('ideogram_realistic.jpg');
      Writeln('OK -> ideogram_realistic.jpg');
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Ideogram Direct Demo                   ');
    Writeln('========================================');
    Writeln;
    RunDesign;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunRealistic;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
