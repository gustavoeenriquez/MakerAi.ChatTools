program AssemblyAIChatTool;

// Demo 02 - AssemblyAI integrado como SpeechTool en TAiChatConnection
//
// Flujo del bridge STT automático:
//   1. El usuario envia un mensaje con un archivo de audio adjunto
//   2. RunNew detecta: ModelCaps=[] + SessionCaps=[cap_Audio]
//      -> GAP=[cap_Audio] -> InternalRunTranscription
//   3. AssemblyAI transcribe el audio (3 pasos internos)
//   4. La transcripción queda como contexto
//   5. El LLM responde basandose en la transcripción
//
// REQUISITOS:
//   1. Variables de entorno ASSEMBLYAI_API_KEY y CLAUDE_API_KEY (o el driver elegido)
//   2. Un archivo de audio en TEST_AUDIO_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.AiConnection,
  uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.AssemblyAI;

const
  TEST_AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunDemo;
var
  Conn  : TAiChatConnection;
  Tool  : TAiAssemblyAISTTTool;
  Media : TAiMediaFile;
  Resp  : String;
begin
  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: archivo de audio no encontrado: ', TEST_AUDIO_FILE);
    Writeln('Modifica la constante TEST_AUDIO_FILE.');
    Exit;
  end;

  Tool  := TAiAssemblyAISTTTool.Create(nil);
  Conn  := TAiChatConnection.Create(nil);
  Media := TAiMediaFile.Create(nil);
  try
    // Configurar AssemblyAI
    Tool.ApiKey       := '@ASSEMBLYAI_API_KEY';
    Tool.Model        := 'best';
    Tool.LanguageCode := 'es';

    // Configurar el chat
    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';

    // Gap = [cap_Audio]:
    //   ModelCaps=[] -> Claude no puede procesar audio nativo aqui
    //   SessionCaps=[cap_Audio] -> queremos procesar audio en esta sesion
    //   Resultado: RunNew activa InternalRunTranscription -> usa AssemblyAI
    Conn.Params.Values['ModelCaps']   := '[]';
    Conn.Params.Values['SessionCaps'] := '[cap_Audio]';

    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'El usuario te enviara la transcripción de un audio. ' +
      'Responde preguntas sobre su contenido de forma clara y concisa.';

    // Cargar el audio como archivo adjunto
    Media.LoadFromFile(TEST_AUDIO_FILE);

    Writeln('Audio   : ', TEST_AUDIO_FILE);
    Writeln('Prompt  : Por favor resume el contenido de este audio');
    Writeln('Procesando (transcripción + LLM)...');
    Writeln;

    // El bridge transcribira el audio antes de enviarlo al LLM
    Resp := Conn.AddMessageAndRun(
      'Por favor resume el contenido de este audio',
      'user',
      [Media]);  // Media adjunto al mensaje

    Writeln('=== Respuesta del LLM ===');
    Writeln(Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free;
    Tool.Free;
    // Nota: Media fue pasado al chat — no liberar aqui si el chat toma ownership
    Media.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' AssemblyAI via ChatTools Demo          ');
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
