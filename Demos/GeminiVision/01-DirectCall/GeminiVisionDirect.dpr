program GeminiVisionDirect;

// Demo 01 - Llamado directo a TAiGeminiVisionTool
// Imagen como inlineData base64 — idéntico patron que GeminiSpeech STT.
// REQUISITO: GEMINI_API_KEY + TEST_IMAGE_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.GeminiVision;

const
  TEST_IMAGE = 'C:\test_image.jpg';

procedure RunVision(const APrompt: String);
var
  Tool  : TAiGeminiVisionTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  if not FileExists(TEST_IMAGE) then
  begin
    Writeln('OMITIDO: ', TEST_IMAGE, ' no encontrado.'); Exit;
  end;
  Tool   := TAiGeminiVisionTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@GEMINI_API_KEY';
    Tool.Model  := 'gemini-2.5-flash';
    AskMsg.Prompt := APrompt;
    Media.LoadFromFile(TEST_IMAGE);
    Write('Analizando... ');
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
    Writeln(' Gemini Vision Direct Demo            ');
    Writeln('======================================');
    Writeln;
    Writeln('--- Descripción general ---');
    RunVision('Describe esta imagen detalladamente, incluyendo colores, objetos y escena.');
    Writeln;
    Writeln('--- Análisis especifico ---');
    RunVision('Hay texto visible en esta imagen? Si es asi, transcribelo.');
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
