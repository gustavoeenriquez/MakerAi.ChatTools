program DeepgramChatTool;

// Demo 02 - Deepgram integrado como SpeechTool en TAiChatConnection
//
// Deepgram (síncrono) vs AssemblyAI (polling): el bridge se activa igual,
// pero Deepgram responde mucho mas rápido al ser una sola llamada HTTP.
//
// REQUISITOS:
//   1. Variables de entorno DEEPGRAM_API_KEY y la clave del driver LLM
//   2. Un archivo de audio en TEST_AUDIO_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Deepgram;

const
  TEST_AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunDemo;
var
  Conn : TAiChatConnection;
  Tool : TAiDeepgramSTTTool;
  Media: TAiMediaFile;
  Resp : String;
begin
  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: archivo de audio no encontrado: ', TEST_AUDIO_FILE);
    Exit;
  end;

  Tool  := TAiDeepgramSTTTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    // Configurar Deepgram
    Tool.ApiKey      := '@DEEPGRAM_API_KEY';
    Tool.Model       := 'nova-3';
    Tool.Language    := 'es';
    Tool.SmartFormat := True;
    Tool.Punctuate   := True;

    // Configurar el chat
    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Audio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Se te proporcionara la transcripción de un audio grabado. ' +
      'Analiza su contenido y responde las preguntas del usuario.';

    Media.LoadFromFile(TEST_AUDIO_FILE);

    Writeln('Audio  : ', TEST_AUDIO_FILE);
    Writeln('Prompt : Que puntos principales se mencionan en el audio?');
    Writeln('Procesando (Deepgram rápido + GPT)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Que puntos principales se mencionan en el audio?',
      'user',
      [Media]);

    Writeln('=== Respuesta del LLM ===');
    Writeln(Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free;
    Tool.Free;
    Media.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Deepgram via ChatTools Demo            ');
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
