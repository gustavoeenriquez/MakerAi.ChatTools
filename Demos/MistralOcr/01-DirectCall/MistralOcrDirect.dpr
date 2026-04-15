program MistralOcrDirect;

// Demo 01 - Llamado directo a TAiMistralOcrTool
// Mistral OCR: endpoint /v1/ocr dedicado (NO /v1/chat/completions).
// Síncrono — una sola llamada HTTP, respuesta inmediata.
// REQUISITO: MISTRAL_API_KEY + TEST_PDF_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.MistralOcr;

const
  TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunFullOcr;
var
  Tool  : TAiMistralOcrTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- OCR completo (todas las páginas) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_PDF_FILE, ' no encontrado.'); Exit;
  end;
  Tool   := TAiMistralOcrTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey := '@MISTRAL_API_KEY';
    Tool.Model  := 'mistral-ocr-latest';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('Archivo : ', TEST_PDF_FILE);
    Write('Procesando (síncrono, /v1/ocr)... ');
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln('Caracteres extraidos: ', Length(ResMsg.Prompt));
    Writeln(Copy(ResMsg.Prompt, 1, 2000));
    if Length(ResMsg.Prompt) > 2000 then
      Writeln('[... ', Length(ResMsg.Prompt) - 2000, ' caracteres mas ...]');
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunTargetPages;
var
  Tool  : TAiMistralOcrTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- OCR de páginas especificas (0 y 1) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.'); Exit;
  end;
  Tool   := TAiMistralOcrTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey      := '@MISTRAL_API_KEY';
    Tool.TargetPages := '0,1';  // Solo primera y segunda pagina

    Media.LoadFromFile(TEST_PDF_FILE);
    Write('Procesando páginas 0 y 1... ');
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln(Copy(ResMsg.Prompt, 1, 1000));
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Mistral OCR Direct Demo                ');
    Writeln('========================================');
    Writeln;
    RunFullOcr;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunTargetPages;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
