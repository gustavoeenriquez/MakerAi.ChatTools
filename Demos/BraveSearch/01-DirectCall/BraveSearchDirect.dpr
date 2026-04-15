program BraveSearchDirect;

// Demo 01 - Llamado directo a TAiBraveSearchTool
// Muestra el uso de Brave Search sin TAiChatConnection.
// Requisito: variable de entorno BRAVE_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.BraveSearch;

procedure RunSimpleSearch;
var
  Tool  : TAiBraveSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Búsqueda simple (Google alternativo) ---');
  Tool   := TAiBraveSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey     := '@BRAVE_API_KEY';
    Tool.Count      := 5;
    Tool.Safesearch := 'moderate';

    AskMsg.Prompt := 'best open source LLM models 2025';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Buscando ...');
    Writeln;
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunFilteredSearch;
var
  Tool  : TAiBraveSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Búsqueda filtrada por idioma y pais ---');
  Tool   := TAiBraveSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey     := '@BRAVE_API_KEY';
    Tool.Count      := 3;
    Tool.SearchLang := 'es';
    Tool.Country    := 'MX';

    AskMsg.Prompt := 'mejores frameworks de inteligencia artificial en Delphi';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Filtro  : idioma=es, pais=MX');
    Writeln('Buscando ...');
    Writeln;
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Brave Search Direct Demo               ');
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
      Writeln('ERROR: ', E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
  Writeln;
  Write('Presiona Enter para salir...');
  Readln;
end.
