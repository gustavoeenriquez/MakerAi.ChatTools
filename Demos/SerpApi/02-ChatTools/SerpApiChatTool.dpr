program SerpApiChatTool;

// Demo 02 - SerpAPI integrado como WebSearchTool en TAiChatConnection
// Requisitos: SERPAPI_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.SerpApi;

procedure RunDemo;
var
  Conn   : TAiChatConnection;
  SerpApi: TAiSerpApiWebSearchTool;
  Resp   : String;
begin
  SerpApi := TAiSerpApiWebSearchTool.Create(nil);
  Conn    := TAiChatConnection.Create(nil);
  try
    SerpApi.ApiKey     := '@SERPAPI_API_KEY';
    SerpApi.Engine     := 'google';
    SerpApi.NumResults := 5;
    SerpApi.Hl         := 'es';
    SerpApi.Gl         := 'mx';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := SerpApi;
    Conn.SystemPrompt.Text :=
      'Responde usando información actualizada de la web via Google. ' +
      'Sé conciso y cita las fuentes.';

    Writeln('Pregunta: Que novedades tiene Delphi 13 Florence?');
    Writeln('Procesando...');
    Writeln;
    Resp := Conn.AddMessageAndRun(
      'Que novedades tiene Delphi 13 Florence?', 'user', []);
    Writeln(Resp);
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    SerpApi.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' SerpAPI via ChatTools Demo             ');
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
