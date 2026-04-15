program LlamaParseChatTool;

// Demo 02 - LlamaParse integrado como PdfTool via bridge cap_Pdf
// Flujo: PDF adjunto -> LlamaParse extrae texto -> LLM responde sobre el contenido
// REQUISITO: LLAMA_CLOUD_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.LlamaParse;

const
  TEST_PDF_FILE = 'C:\test_document.pdf';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiLlamaParseToolPdf;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_PDF_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_PDF_FILE, ' no encontrado.');
    Exit;
  end;

  Tool  := TAiLlamaParseToolPdf.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey     := '@LLAMA_CLOUD_API_KEY';
    Tool.ResultType := 'markdown';
    Tool.Language   := 'es';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_Pdf]: LlamaParse extrae el texto del PDF antes de enviarlo al LLM
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Pdf]';
    Conn.PdfTool := Tool;
    Conn.SystemPrompt.Text :=
      'Analiza el contenido del documento PDF y responde las preguntas del usuario. ' +
      'Cita secciones específicas cuando sea relevante.';

    Media.LoadFromFile(TEST_PDF_FILE);

    Writeln('PDF    : ', TEST_PDF_FILE);
    Writeln('Pregunta: Resume los puntos principales de este documento');
    Writeln('Procesando (LlamaParse + Claude)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Resume los puntos principales de este documento',
      'user', [Media]);

    Writeln('=== Respuesta ===');
    Writeln(Resp);
  finally
    Conn.PdfTool := nil;
    Conn.Free; Tool.Free; Media.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' LlamaParse via ChatTools Demo          ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
