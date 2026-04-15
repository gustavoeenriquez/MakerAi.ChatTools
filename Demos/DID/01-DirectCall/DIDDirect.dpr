program DIDDirect;

// Demo 01 - Llamado directo a TAiDIDVideoTool
// D-ID: avatares hablantes — imagen + texto = video del avatar.
// AUTENTICACION: Basic Auth con api_key como usuario, password vacío.
// REQUISITO: DID_API_KEY + URL de imagen de avatar (DriverUrl)

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.DID;

const
  // Imagen de muestra de D-ID para pruebas (imagen publica de ejemplo)
  SAMPLE_AVATAR = 'https://create-images-results.d-id.com/DefaultPresenters/Noelle_f/image.jpeg';

procedure RunAvatarES;
var
  Tool  : TAiDIDVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Avatar hablante en español ---');
  Tool   := TAiDIDVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey        := '@DID_API_KEY';
    Tool.DriverUrl     := SAMPLE_AVATAR;
    Tool.ProviderType  := 'microsoft';
    Tool.ProviderVoice := 'es-MX-DaliaNeural';
    Tool.ResultFormat  := 'mp4';

    AskMsg.Prompt :=
      'Bienvenidos al futuro de la inteligencia artificial. ' +
      'Soy un avatar digital creado con tecnologia D-ID. ' +
      'Hoy les mostrare como la IA puede transformar la comunicacion empresarial.';

    Writeln('Texto: ', Copy(AskMsg.Prompt, 1, 60), '...');
    Writeln('Avatar: ', SAMPLE_AVATAR);
    Writeln('Procesando (submit + polling ~15-60 seg)...');
    Writeln;

    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
    begin
      Writeln('Video generado!');
      Writeln('URL: ', ResMsg.Prompt);
    end;
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

procedure RunAvatarEN;
var
  Tool  : TAiDIDVideoTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Writeln('--- Avatar hablante en ingles ---');
  Tool   := TAiDIDVideoTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey        := '@DID_API_KEY';
    Tool.DriverUrl     := SAMPLE_AVATAR;
    Tool.ProviderType  := 'microsoft';
    Tool.ProviderVoice := 'en-US-JennyNeural';

    AskMsg.Prompt :=
      'Hello everyone! I am an AI avatar powered by D-ID. ' +
      'Digital humans are transforming how we create video content at scale.';

    Writeln('Procesando...');
    Tool.ExecuteVideoGeneration(ResMsg, AskMsg);

    if ResMsg.Prompt <> '' then
      Writeln('Video URL: ', ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' D-ID Talking Avatar Direct Demo        ');
    Writeln('========================================');
    Writeln;
    RunAvatarES;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunAvatarEN;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
