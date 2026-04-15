program PerplexityDirect;

// Demo 01 - Llamado directo a TAiPerplexitySonarTool
// Perplexity ya devuelve una respuesta sintetizada, no lista de resultados crudos.
// Requisito: variable de entorno PERPLEXITY_API_KEY

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.PerplexitySonar;

procedure RunSonarBasic;
var
  Tool  : TAiPerplexitySonarTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Sonar básico (respuesta rapida) ---');
  Tool   := TAiPerplexitySonarTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey    := '@PERPLEXITY_API_KEY';
    Tool.Model     := 'sonar';
    Tool.MaxTokens := 512;

    AskMsg.Prompt := 'What are the top AI coding assistants in 2025?';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Modelo  : sonar');
    Writeln('Procesando...');
    Writeln;
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunSonarWithRecency;
var
  Tool  : TAiPerplexitySonarTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Sonar con filtro de recencia (ultima semana) ---');
  Tool   := TAiPerplexitySonarTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey              := '@PERPLEXITY_API_KEY';
    Tool.Model               := 'sonar-pro';
    Tool.MaxTokens           := 1024;
    // Solo noticias de la ultima semana
    Tool.SearchRecencyFilter := 'week';

    AskMsg.Prompt := 'latest news about large language models';
    Writeln('Pregunta: ', AskMsg.Prompt);
    Writeln('Modelo  : sonar-pro | Recencia: semana');
    Writeln('Procesando...');
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
    Writeln(' Perplexity Sonar Direct Demo           ');
    Writeln('========================================');
    Writeln;
    RunSonarBasic;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunSonarWithRecency;
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
