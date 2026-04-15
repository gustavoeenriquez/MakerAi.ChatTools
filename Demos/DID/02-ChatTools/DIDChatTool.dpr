program DIDChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.DID;

const
  SAMPLE_AVATAR = 'https://create-images-results.d-id.com/DefaultPresenters/Noelle_f/image.jpeg';

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiDIDVideoTool;
  Resp: String;
begin
  Tool := TAiDIDVideoTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey        := '@DID_API_KEY';
    Tool.DriverUrl     := SAMPLE_AVATAR;
    Tool.ProviderType  := 'microsoft';
    Tool.ProviderVoice := 'es-MX-DaliaNeural';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenVideo]';
    Conn.VideoTool := Tool;
    Conn.SystemPrompt.Text :=
      'Redacta el guion de un avatar virtual en español, en maximo 2-3 oraciones. ' +
      'El texto sera hablado por el avatar, asi que debe sonar natural y conversacional.';

    Writeln('Solicitud: Crea un video donde el avatar presenta MakerAI');
    Writeln('Procesando (GPT redacta guion + D-ID genera avatar)...');
    Resp := Conn.AddMessageAndRun(
      'Crea un video donde el avatar presenta el framework MakerAI para Delphi',
      'user', []);
    Writeln('Descripción/URL: ', Resp);
  finally
    Conn.VideoTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' D-ID via ChatTools Demo                ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
