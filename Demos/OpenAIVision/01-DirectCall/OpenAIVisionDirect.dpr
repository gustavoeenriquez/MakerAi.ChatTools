program OpenAIVisionDirect;

// Demo 01 - Llamado directo a TAiOpenAIVisionTool
// Imagen como data URL base64 en content[].image_url.
// REQUISITO: OPENAI_API_KEY + TEST_IMAGE_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.OpenAIVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunVision(const APrompt, ADetail: String);
var
  Tool  : TAiOpenAIVisionTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool   := TAiOpenAIVisionTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@OPENAI_API_KEY';
    Tool.Model    := 'gpt-4o-mini';
    Tool.Detail   := ADetail;
    AskMsg.Prompt := APrompt;
    Media.LoadFromFile(TEST_IMAGE);
    Write('Analizando [detail=' + ADetail + ']... ');
    Tool.ExecuteImageDescription(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln(ResMsg.Prompt);
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' OpenAI Vision Direct Demo            ');
    Writeln('======================================');
    Writeln;
    Writeln('--- Descripción general (auto) ---');
    RunVision('Describe esta imagen detalladamente.', 'auto');
    Writeln;
    Writeln('--- Pregunta especifica (low) ---');
    RunVision('Cuantos objetos hay en la imagen? Lista los principales.', 'low');
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
