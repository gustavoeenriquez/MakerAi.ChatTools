program ClaudeVisionDirect;

// Demo 01 - Llamado directo a TAiClaudeVisionTool
// DIFERENCIA vs OpenAI/Gemini: bloque imagen VA PRIMERO, texto despues.
// REQUISITO: CLAUDE_API_KEY + TEST_IMAGE_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.ClaudeVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunVision(const APrompt: String);
var
  Tool  : TAiClaudeVisionTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool   := TAiClaudeVisionTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@CLAUDE_API_KEY';
    Tool.Model  := 'claude-haiku-4-5-20251001';
    AskMsg.Prompt := APrompt;
    Media.LoadFromFile(TEST_IMAGE);
    Write('Analizando (imagen primero, texto despues)... ');
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
    Writeln(' Claude Vision Direct Demo            ');
    Writeln('======================================');
    Writeln;
    Writeln('--- Descripción detallada ---');
    RunVision('Describe esta imagen con el mayor detalle posible.');
    Writeln;
    Writeln('--- Identificar objetos ---');
    RunVision('Lista todos los objetos que puedes identificar en la imagen.');
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
