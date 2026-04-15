program SerpApiDirect;

// Demo 01 - Llamado directo a TAiSerpApiWebSearchTool
// Muestra Google y Bing como motores alternativos.
// Requisito: variable de entorno SERPAPI_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.SerpApi;

procedure RunGoogleSearch;
var
  Tool  : TAiSerpApiWebSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Google (engine=google) ---');
  Tool   := TAiSerpApiWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey     := '@SERPAPI_API_KEY';
    Tool.Engine     := 'google';
    Tool.NumResults := 5;
    Tool.Hl         := 'es';
    Tool.Gl         := 'mx';

    AskMsg.Prompt := 'Delphi programming AI integration 2025';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Buscando ...');
    Writeln;
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunBingSearch;
var
  Tool  : TAiSerpApiWebSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Bing (engine=bing) ---');
  Tool   := TAiSerpApiWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey     := '@SERPAPI_API_KEY';
    Tool.Engine     := 'bing';
    Tool.NumResults := 3;

    AskMsg.Prompt := 'MakerAI Delphi framework open source';
    Writeln('Pregunta: ', AskMsg.Prompt);
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
    Writeln(' SerpAPI Direct Demo                    ');
    Writeln('========================================');
    Writeln;
    RunGoogleSearch;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunBingSearch;
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
