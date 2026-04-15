program FishAudioChatTool;

// Demo 02 - Fish Audio integrado como SpeechTool via bridge cap_GenAudio
// REQUISITO: FISHAUDIO_API_KEY + ReferenceId + clave del driver LLM

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.FishAudio;

const
  REFERENCE_ID = '';  // <- Asignar ReferenceId valido de Fish Audio

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiFishAudioTTSTool;
  Resp: String;
begin
  if REFERENCE_ID.IsEmpty then
  begin
    Writeln('OMITIDO: asignar REFERENCE_ID.');
    Exit;
  end;

  Tool := TAiFishAudioTTSTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey      := '@FISHAUDIO_API_KEY';
    Tool.ReferenceId := REFERENCE_ID;
    Tool.Format      := 'mp3';
    Tool.Latency     := 'balanced';  // mas rápido para demos

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenAudio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde de forma muy breve (1-2 oraciones) en español sin formato especial.';

    Writeln('Pregunta: Cuantos planetas tiene el sistema solar?');
    Write('Procesando (Claude + Fish Audio TTS)...');
    Resp := Conn.AddMessageAndRun(
      'Cuantos planetas tiene el sistema solar?', 'user', []);
    Writeln;
    Writeln('Texto: ', Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Fish Audio via ChatTools Demo          ');
    Writeln('========================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
