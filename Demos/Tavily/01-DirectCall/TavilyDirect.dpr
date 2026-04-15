program TavilyDirect;

// Demo 01 — Llamado directo a TAiTavilyWebSearchTool
//
// Muestra cómo usar la herramienta de forma independiente, sin TAiChatConnection
// ni ningun chat involucrado. Útil para:
//   - Validar la API key y la conectividad con Tavily
//   - Ver el formato crudo de los resultados antes de integrarlo al chat
//   - Usar Tavily como servicio de búsqueda standalone
//
// Requisito: variable de entorno TAVILY_API_KEY con tu clave de Tavily.
// Obtener en: https://app.tavily.com

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Tavily;

// ---------------------------------------------------------------------------
// Demo: búsqueda simple
// ---------------------------------------------------------------------------
procedure RunSimpleSearch;
var
  Tool   : TAiTavilyWebSearchTool;
  AskMsg : TAiChatMessage;
  ResMsg : TAiChatMessage;
begin
  Writeln('--- Búsqueda simple ---');

  Tool   := TAiTavilyWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey       := '@TAVILY_API_KEY';
    Tool.SearchDepth  := tsdBasic;
    Tool.MaxResults   := 5;
    Tool.IncludeAnswer := True;

    AskMsg.Prompt := 'What are the most important AI models released in 2025?';

    Writeln('Pregunta : ', AskMsg.Prompt);
    Writeln('Buscando ...');
    Writeln;

    // Llamado directo: sin contexto de chat, sin bridge autom?tico
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);

    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free;
    AskMsg.Free;
    Tool.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Demo: búsqueda avanzada con filtro de dominios
// ---------------------------------------------------------------------------
procedure RunFilteredSearch;
var
  Tool   : TAiTavilyWebSearchTool;
  AskMsg : TAiChatMessage;
  ResMsg : TAiChatMessage;
begin
  Writeln('--- Búsqueda avanzada con filtro de dominios ---');

  Tool   := TAiTavilyWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey       := '@TAVILY_API_KEY';
    Tool.SearchDepth  := tsdAdvanced;
    Tool.MaxResults   := 3;
    Tool.IncludeAnswer := True;

    // Solo resultados de estos dominios
    Tool.IncludeDomains.Add('arxiv.org');
    Tool.IncludeDomains.Add('huggingface.co');

    AskMsg.Prompt := 'transformer architecture improvements 2025';

    Writeln('Pregunta : ', AskMsg.Prompt);
    Writeln('Dominios : arxiv.org, huggingface.co');
    Writeln('Buscando ...');
    Writeln;

    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);

    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free;
    AskMsg.Free;
    Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Tavily Direct Search Demo              ');
    Writeln('========================================');
    Writeln;

    RunSimpleSearch;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunFilteredSearch;

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
