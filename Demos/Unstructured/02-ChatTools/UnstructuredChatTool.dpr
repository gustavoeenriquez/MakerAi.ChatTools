program UnstructuredChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Unstructured;

const TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiUnstructuredPdfTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_PDF_FILE, ' no encontrado.');
    Exit;
  end;

  Tool  := TAiUnstructuredPdfTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey   := '@UNSTRUCTURED_API_KEY';
    Tool.Strategy := 'auto';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Pdf]';
    Conn.PdfTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde preguntas sobre el documento de forma clara y estructurada.';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('Pregunta: De que trata este documento y cuales son sus secciones?');
    Writeln('Procesando (Unstructured + Claude)...');
    Resp := Conn.AddMessageAndRun(
      'De que trata este documento y cuales son sus secciones?',
      'user', [Media]);
    Writeln(Resp);
  finally
    Conn.PdfTool := nil;
    Conn.Free; Tool.Free; Media.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Unstructured via ChatTools Demo        ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
