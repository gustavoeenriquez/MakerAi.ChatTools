program CartesiaChatTool;

// Demo 02 - Cartesia integrado como SpeechTool via bridge cap_GenAudio
// REQUISITO: CARTESIA_API_KEY + VoiceId valido + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.Cartesia;

const
  VOICE_ID_ES = '';  // <- Asignar VoiceId valido de https://play.cartesia.ai

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiCartesiaTTSTool;
  Resp: String;
begin
  if VOICE_ID_ES.IsEmpty then
  begin
    Writeln('OMITIDO: asignar VOICE_ID_ES en el codigo fuente.');
    Exit;
  end;

  Tool := TAiCartesiaTTSTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey     := '@CARTESIA_API_KEY';
    Tool.ModelId    := 'sonic-2';
    Tool.VoiceId    := VOICE_ID_ES;
    Tool.Language   := 'es';

    Conn.DriverName := 'OpenAi';
    Conn.Model      := 'gpt-4.1-mini';
    Conn.Params.Values['ApiKey']       := '@OPENAI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenAudio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde brevemente y en español, como si hablaras directamente.';

    Writeln('Pregunta: Que es la inteligencia artificial?');
    Writeln('Procesando (GPT + Cartesia TTS)...');
    Resp := Conn.AddMessageAndRun(
      'Que es la inteligencia artificial?', 'user', []);
    Writeln('Texto: ', Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Cartesia via ChatTools Demo            ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
