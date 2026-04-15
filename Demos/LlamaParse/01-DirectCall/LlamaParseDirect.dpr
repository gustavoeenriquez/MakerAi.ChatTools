program LlamaParseDirect;

// Demo 01 - Llamado directo a TAiLlamaParseToolPdf
// LlamaParse: el mejor parser para PDFs complejos (tablas, columnas, formulas).
// REQUISITO: LLAMA_CLOUD_API_KEY + TEST_PDF_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.LlamaParse;

const
  TEST_PDF_FILE = 'C:\test_document.pdf';  // Cambiar a un PDF real

procedure RunMarkdownParse;
var
  Tool  : TAiLlamaParseToolPdf;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Parseo a Markdown (preserva estructura) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_PDF_FILE, ' no encontrado.');
    Exit;
  end;

  Tool   := TAiLlamaParseToolPdf.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey     := '@LLAMA_CLOUD_API_KEY';
    Tool.ResultType := 'markdown';
    Tool.Language   := 'es';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('Archivo: ', TEST_PDF_FILE);
    Writeln('Procesando (upload + polling + resultado)...');
    Writeln;
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);

    Writeln('=== Resultado (primeros 2000 caracteres) ===');
    Writeln(Copy(ResMsg.Prompt, 1, 2000));
    if Length(ResMsg.Prompt) > 2000 then
      Writeln('[... ', Length(ResMsg.Prompt) - 2000, ' caracteres mas...]');
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunPremiumMode;
var
  Tool  : TAiLlamaParseToolPdf;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Parseo con modo premium (mayor precisión) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.');
    Exit;
  end;

  Tool   := TAiLlamaParseToolPdf.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey       := '@LLAMA_CLOUD_API_KEY';
    Tool.ResultType   := 'markdown';
    Tool.PremiumMode  := True;  // Mayor precisión para tablas y formulas
    Tool.SkipDiagonalText := True;  // Omitir watermarks

    Media.LoadFromFile(TEST_PDF_FILE);
    Writeln('Procesando con modo premium...');
    Writeln;
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);

    Writeln('Caracteres extraidos: ', Length(ResMsg.Prompt));
    Writeln(Copy(ResMsg.Prompt, 1, 1000));
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' LlamaParse PDF Direct Demo             ');
    Writeln('========================================');
    Writeln;
    RunMarkdownParse;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunPremiumMode;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
