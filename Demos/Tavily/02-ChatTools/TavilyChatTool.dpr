program TavilyChatTool;

// Demo 02 — Tavily integrado como WebSearchTool en TAiChatConnection
//
// Muestra el flujo completo del bridge automático de ChatTools:
//
//   SessionCaps = [cap_WebSearch]
//   ModelCaps   = []                      <- el modelo no tiene búsqueda nativa
//   GAP         = [cap_WebSearch]         <- RunNew detecta el gap
//                     |
//                     v
//   InternalRunWebSearch()
//     -> TAiTavilyWebSearchTool.ExecuteSearch(pregunta)
//     -> Resultado inyectado en contexto
//                     |
//                     v
//   InternalRunCompletions()              <- LLM genera respuesta final con contexto
//
// Requisitos:
//   - Variable de entorno TAVILY_API_KEY
//   - Variable de entorno del driver LLM elegido (p.ej. CLAUDE_API_KEY)

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Tavily;

// ---------------------------------------------------------------------------
// Demo: pregunta con búsqueda web via bridge automático
// ---------------------------------------------------------------------------
procedure RunWithWebSearch(const ADriver, AModel, AApiKey: String);
var
  Conn  : TAiChatConnection;
  Tavily: TAiTavilyWebSearchTool;
  Resp  : String;
begin
  Writeln('Driver : ', ADriver);
  Writeln('Modelo : ', AModel);
  Writeln;

  Tavily := TAiTavilyWebSearchTool.Create(nil);
  Conn   := TAiChatConnection.Create(nil);
  try
    // --- Configurar Tavily ---
    Tavily.ApiKey       := '@TAVILY_API_KEY';
    Tavily.SearchDepth  := tsdAdvanced;
    Tavily.MaxResults   := 5;
    Tavily.IncludeAnswer := True;

    // --- Configurar el chat ---
    Conn.DriverName := ADriver;
    Conn.Model      := AModel;
    Conn.Params.Values['ApiKey']       := AApiKey;
    Conn.Params.Values['Asynchronous'] := 'False';

    // Gap = [cap_WebSearch]:
    //   ModelCaps=[]   -> el modelo NO tiene búsqueda web nativa
    //   SessionCaps=[cap_WebSearch] -> queremos búsqueda web en esta sesión
    //   Resultado: RunNew activa InternalRunWebSearch -> usa Tavily
    Conn.Params.Values['ModelCaps']   := '[]';
    Conn.Params.Values['SessionCaps'] := '[cap_WebSearch]';

    // Asignar la herramienta al slot WebSearchTool de ChatTools
    Conn.WebSearchTool := Tavily;

    Conn.SystemPrompt.Text :=
      'Eres un asistente que responde usando información actualizada de la web. ' +
      'Cuando uses resultados de búsqueda, menciona las fuentes con su URL.';

    // --- Pregunta 1: información reciente ---
    Writeln('=== Pregunta 1 ===');
    Writeln('¿Cuáles son los modelos de IA más importantes lanzados en 2025?');
    Writeln('Procesando...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      '¿Cuáles son los modelos de IA más importantes lanzados en 2025?',
      'user', []);
    Writeln(Resp);
    Writeln;

    // --- Pregunta 2: seguimiento (historial activo) ---
    Writeln('=== Pregunta 2 (seguimiento) ===');
    Writeln('¿Cuál de ellos tiene mejor rendimiento en razonamiento?');
    Writeln('Procesando...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      '¿Cuál de ellos tiene mejor rendimiento en razonamiento?',
      'user', []);
    Writeln(Resp);

  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Tavily.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Tavily via ChatTools Demo              ');
    Writeln('========================================');
    Writeln;

    // Cambiar driver/modelo/apikey seg?n el proveedor que quieras usar
    RunWithWebSearch(
      'Claude',
      'claude-haiku-4-5-20251001',
      '@CLAUDE_API_KEY'
    );

  except
    on E: Exception do
    begin
      Writeln;
      Writeln('ERROR: ', E.ClassName, ' — ', E.Message);
      ExitCode := 1;
    end;
  end;

  Writeln;
  Write('Presiona Enter para salir...');
  Readln;
end.
