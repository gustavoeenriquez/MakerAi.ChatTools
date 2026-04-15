program ExaDirect;

// Demo 01 - Llamado directo a TAiExaWebSearchTool
// Muestra búsqueda neural con texto completo de páginas (ideal para RAG).
// Requisito: variable de entorno EXA_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Exa;

procedure RunNeuralSearch;
var
  Tool  : TAiExaWebSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Búsqueda neural con texto completo ---');
  Tool   := TAiExaWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey        := '@EXA_API_KEY';
    Tool.NumResults    := 3;
    Tool.UseAutoprompt := True;
    Tool.SearchType    := 'neural';
    Tool.IncludeText   := True;
    Tool.TextMaxChars  := 1500;

    AskMsg.Prompt := 'latest advances in retrieval augmented generation 2025';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Modo    : neural + texto completo');
    Writeln('Buscando ...');
    Writeln;
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunDateFilteredSearch;
var
  Tool  : TAiExaWebSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Búsqueda con filtro de fechas ---');
  Tool   := TAiExaWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey             := '@EXA_API_KEY';
    Tool.NumResults         := 5;
    Tool.SearchType         := 'auto';
    Tool.IncludeText        := False;
    Tool.StartPublishedDate := '2025-01-01';

    AskMsg.Prompt := 'Delphi programming language new features';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Filtro  : publicado desde 2025-01-01');
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
    Writeln(' Exa AI Search Direct Demo              ');
    Writeln('========================================');
    Writeln;
    RunNeuralSearch;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunDateFilteredSearch;
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
