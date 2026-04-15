program ElevenLabsChatTool;

// Demo 02 - ElevenLabs integrado como SpeechTool en TAiChatConnection
//
// Este demo muestra el bridge TTS:
//   ModelCaps=[] + SessionCaps=[cap_GenAudio]
//   -> GAP=[cap_GenAudio] -> InternalRunSpeechGeneration
//   -> ElevenLabs convierte la respuesta del LLM a audio
//
// Flujo completo:
//   1. El usuario hace una pregunta de texto
//   2. El LLM genera la respuesta en texto
//   3. ElevenLabs convierte el texto a audio
//   4. El audio queda en ResMsg.MediaFiles[0]
//
// REQUISITO: ELEVENLABS_API_KEY + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.ElevenLabs;

const OUTPUT_AUDIO = 'response_audio.mp3';

procedure RunDemo;
var
  Conn   : TAiChatConnection;
  Tool   : TAiElevenLabsTool;
  Resp   : String;
begin
  Tool := TAiElevenLabsTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey          := '@ELEVENLABS_API_KEY';
    Tool.VoiceId         := 'JBFqnCBsd6RMkjVDRZzb';
    Tool.TTSModel        := 'eleven_multilingual_v2';
    Tool.OutputFormat    := 'mp3_44100_128';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    // Gap=[cap_GenAudio]: el bridge convertira la respuesta del LLM a audio
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenAudio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde de forma breve y natural, como si estuvieras hablando. ' +
      'No uses markdown, listas ni caracteres especiales.';

    Writeln('Pregunta: Cual es la capital de Mexico y por que es famosa?');
    Writeln('Procesando (LLM + ElevenLabs TTS)...');
    Writeln;

    Resp := Conn.AddMessageAndRun(
      'Cual es la capital de Mexico y por que es famosa?', 'user', []);

    Writeln('Respuesta texto: ', Resp);
    Writeln;

    // El audio generado esta en el mensaje de respuesta
    // Para acceder al audio directamente habria que interceptar OnReceiveDataEnd
    // y acceder al ResMsg.MediaFiles[0].Stream
    Writeln('Nota: el audio se genera internamente en ResMsg.MediaFiles.');
    Writeln('Ver OnReceiveDataEnd del chat para guardar el archivo de audio.');
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' ElevenLabs via ChatTools Demo          ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
