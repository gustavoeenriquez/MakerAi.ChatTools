program PerplexityChatTool;

// Demo 02 - Perplexity Sonar integrado como WebSearchTool en TAiChatConnection
//
// Nota sobre el flujo con Perplexity:
//   - InternalRunWebSearch llama TAiPerplexitySonarTool.ExecuteSearch
//   - Perplexity ya devuelve la respuesta sintetizada en ResMsg.Prompt
//   - El LLM del driver recibe ese texto como contexto y puede elaborar mas
//
// Requisitos: PERPLEXITY_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.PerplexitySonar;

procedure RunDemo;
var
  Conn      : TAiChatConnection;
  Perplexity: TAiPerplexitySonarTool;
  Resp      : String;
begin
  Perplexity := TAiPerplexitySonarTool.Create(nil);
  Conn       := TAiChatConnection.Create(nil);
  try
    Perplexity.ApiKey              := '@PERPLEXITY_API_KEY';
    Perplexity.Model               := 'sonar';
    Perplexity.MaxTokens           := 1024;
    Perplexity.SearchRecencyFilter := 'month';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := Perplexity;
    Conn.SystemPrompt.Text :=
      'Usa la información proporcionada para dar una respuesta clara y estructurada. ' +
      'Agrega contexto adicional cuando sea util.';

    Writeln('Pregunta: Cuáles son las tendencias de IA en desarrollo de software 2025?');
    Writeln('Procesando (Perplexity Sonar + Claude)...');
    Writeln;
    Resp := Conn.AddMessageAndRun(
      'Cuáles son las tendencias de IA en desarrollo de software 2025?',
      'user', []);
    Writeln(Resp);
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Perplexity.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Perplexity Sonar via ChatTools Demo    ');
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
