program BraveSearchChatTool;

// Demo 02 - Brave Search integrado como WebSearchTool en TAiChatConnection
// Gap: ModelCaps=[] + SessionCaps=[cap_WebSearch] -> usa TAiBraveSearchTool
// Requisitos: BRAVE_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.BraveSearch;

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Brave: TAiBraveSearchTool;
  Resp : String;
begin
  Brave := TAiBraveSearchTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  try
    Brave.ApiKey     := '@BRAVE_API_KEY';
    Brave.Count      := 5;
    Brave.SearchLang := 'es';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := Brave;
    Conn.SystemPrompt.Text :=
      'Eres un asistente que responde con información actualizada de la web. ' +
      'Menciona las fuentes cuando uses resultados de búsqueda.';

    Writeln('Pregunta: Cuáles son los modelos de IA mas importantes de 2025?');
    Writeln('Procesando...');
    Writeln;
    Resp := Conn.AddMessageAndRun(
      'Cuáles son los modelos de IA mas importantes de 2025?', 'user', []);
    Writeln(Resp);
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Brave.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Brave Search via ChatTools Demo        ');
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
