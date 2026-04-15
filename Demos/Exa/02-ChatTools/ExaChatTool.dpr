program ExaChatTool;

// Demo 02 - Exa integrado como WebSearchTool en TAiChatConnection
// Exa con IncludeText=True provee contexto mas rico que otros motores.
// Requisitos: EXA_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Exa;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Exa : TAiExaWebSearchTool;
  Resp: String;
begin
  Exa  := TAiExaWebSearchTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Exa.ApiKey       := '@EXA_API_KEY';
    Exa.NumResults   := 4;
    Exa.SearchType   := 'auto';
    Exa.IncludeText  := True;
    Exa.TextMaxChars := 1000;

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := Exa;
    Conn.SystemPrompt.Text :=
      'Usa el contenido completo de las fuentes para dar respuestas detalladas y precisas. ' +
      'Cita las URLs de las fuentes que uses.';

    Writeln('Pregunta: Como implementar un sistema RAG con Delphi?');
    Writeln('Procesando (Exa con texto completo)...');
    Writeln;
    Resp := Conn.AddMessageAndRun(
      'Como implementar un sistema RAG con Delphi?', 'user', []);
    Writeln(Resp);
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Exa.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Exa AI Search via ChatTools Demo       ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
  Writeln;
  Write('Presiona Enter para salir...');
  Readln;
end.
