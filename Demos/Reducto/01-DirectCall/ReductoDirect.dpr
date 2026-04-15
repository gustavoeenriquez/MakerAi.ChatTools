program ReductoDirect;

// Demo 01 - Llamado directo a TAiReductoPdfTool
// Reducto: alta precisión para documentos financieros y legales.
// Request usa base64 en JSON (no multipart). Respuesta generalmente sincrona.
// REQUISITO: REDUCTO_API_KEY + TEST_PDF_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Reducto;

const
  TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunOcrMode;
var
  Tool  : TAiReductoPdfTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Modo OCR (rápido) con extracción de tablas ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.');
    Exit;
  end;

  Tool   := TAiReductoPdfTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey        := '@REDUCTO_API_KEY';
    Tool.ParseMode     := 'ocr';
    Tool.OutputFormat  := 'markdown';
    Tool.ExtractTables := True;
    Tool.FigureMode    := 'ignore';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('Archivo: ', TEST_PDF_FILE);
    Write('Analizando (base64 + síncrono)... ');
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln('Caracteres: ', Length(ResMsg.Prompt));
    Writeln(Copy(ResMsg.Prompt, 1, 1500));
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunAccurateMode;
var
  Tool  : TAiReductoPdfTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Modo Accurate (mayor precisión) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.');
    Exit;
  end;

  Tool   := TAiReductoPdfTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey             := '@REDUCTO_API_KEY';
    Tool.ParseMode          := 'accurate';
    Tool.OutputFormat       := 'markdown';
    Tool.ExtractTables      := True;
    Tool.IncludePageNumbers := True;
    Tool.FigureMode         := 'description';

    Media.LoadFromFile(TEST_PDF_FILE);

    Write('Analizando en modo accurate... ');
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln(Copy(ResMsg.Prompt, 1, 1500));
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Reducto PDF Direct Demo                ');
    Writeln('========================================');
    Writeln;
    RunOcrMode;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunAccurateMode;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
