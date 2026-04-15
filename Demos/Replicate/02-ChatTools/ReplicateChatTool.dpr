program ReplicateChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Replicate;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiReplicateImageTool;
  Resp: String;
begin
  Tool := TAiReplicateImageTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey        := '@REPLICATE_API_KEY';
    Tool.ModelVersion  := 'black-forest-labs/flux-schnell';
    Tool.OutputFormat  := 'webp';
    Tool.OutputQuality := 85;

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenImage]';
    Conn.ImageTool := Tool;
    Conn.SystemPrompt.Text :=
      'Genera prompts detallados en ingles para generación de imagen con FLUX. ' +
      'Describe escena, iluminacion, estilo artistico y camara.';

    Writeln('Solicitud: Genera una imagen de un dragon medieval volando sobre un castillo');
    Writeln('Procesando (Claude + Replicate FLUX)...');
    Resp := Conn.AddMessageAndRun(
      'Genera una imagen de un dragon medieval volando sobre un castillo', 'user', []);
    Writeln('Descripción: ', Resp);
  finally
    Conn.ImageTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Replicate via ChatTools Demo           ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
