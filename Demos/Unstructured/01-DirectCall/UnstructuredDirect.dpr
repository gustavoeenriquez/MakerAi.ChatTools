program UnstructuredDirect;

// Demo 01 - Llamado directo a TAiUnstructuredPdfTool
// Unstructured: parser multiformato open-source (PDF, Word, Excel, HTML...).
// Request multipart, respuesta JSON de elementos estructurados.
// DIFERENCIA: header 'unstructured-api-key' (no Authorization)
// REQUISITO: UNSTRUCTURED_API_KEY + TEST_PDF_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Unstructured;

const TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunAutoStrategy;
var
  Tool  : TAiUnstructuredPdfTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Estrategia auto (sin chunking) ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.');
    Exit;
  end;

  Tool   := TAiUnstructuredPdfTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@UNSTRUCTURED_API_KEY';
    Tool.Strategy := 'auto';

    Media.LoadFromFile(TEST_PDF_FILE);

    Write('Analizando (multipart síncrono)... ');
    Tool.ExecutePdfAnalysis(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln('Caracteres: ', Length(ResMsg.Prompt));
    Writeln(Copy(ResMsg.Prompt, 1, 1500));
  finally
    Media.Free; ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunHiResWithChunking;
var
  Tool  : TAiUnstructuredPdfTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Estrategia hi_res con chunking by_title ---');
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: archivo no encontrado.');
    Exit;
  end;

  Tool   := TAiUnstructuredPdfTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey           := '@UNSTRUCTURED_API_KEY';
    Tool.Strategy         := 'hi_res';     // Mayor precisión
    Tool.ChunkingStrategy := 'by_title';   // Divide por titulos
    Tool.MaxCharacters    := 800;          // Max 800 chars por chunk

    Media.LoadFromFile(TEST_PDF_FILE);

    Write('Analizando en hi_res con chunking... ');
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
    Writeln(' Unstructured PDF Direct Demo           ');
    Writeln('========================================');
    Writeln;
    RunAutoStrategy;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunHiResWithChunking;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
