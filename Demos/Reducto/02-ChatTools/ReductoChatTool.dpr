program ReductoChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Reducto;

const TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiReductoPdfTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_PDF_FILE, ' no encontrado.');
    Exit;
  end;

  Tool  := TAiReductoPdfTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey       := '@REDUCTO_API_KEY';
    Tool.ParseMode    := 'accurate';
    Tool.ExtractTables:= True;

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Pdf]';
    Conn.PdfTool := Tool;
    Conn.SystemPrompt.Text :=
      'Analiza el documento y responde con informacion precisa. ' +
      'Si hay tablas numericas, citala exactamente.';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('Pregunta: Cuales son los números o datos mas importantes de este documento?');
    Writeln('Procesando (Reducto accurate + GPT)...');
    Resp := Conn.AddMessageAndRun(
      'Cuales son los números o datos mas importantes de este documento?',
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
    Writeln(' Reducto via ChatTools Demo             ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
