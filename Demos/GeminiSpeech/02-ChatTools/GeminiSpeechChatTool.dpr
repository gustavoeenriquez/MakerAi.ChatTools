program GeminiSpeechChatTool;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
  uMakerAi.ChatTools.GeminiSpeech;

procedure RunDemo;
var
  Conn: TAiChatConnection;
  Tool: TAiGeminiSpeechTool;
  Resp: String;
begin
  Tool := TAiGeminiSpeechTool.Create(nil);
  Conn := TAiChatConnection.Create(nil);
  try
    Tool.ApiKey    := '@GEMINI_API_KEY';
    Tool.TTSModel  := 'gemini-2.5-flash-preview-tts';
    Tool.VoiceName := 'Aoede';

    Conn.DriverName := 'Gemini';
    Conn.Model      := 'gemini-2.5-flash';
    Conn.Params.Values['ApiKey']       := '@GEMINI_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_GenAudio]';
    Conn.SpeechTool := Tool;
    Conn.SystemPrompt.Text :=
      'Responde con una oracion corta y natural, como si hablaras directamente.';

    Writeln('Pregunta: Cual es la capital de Francia?');
    Writeln('Procesando (Gemini genera texto + Gemini TTS lo vocaliza)...');
    Resp := Conn.AddMessageAndRun(
      'Cual es la capital de Francia?', 'user', []);
    Writeln('Texto: ', Resp);
  finally
    Conn.SpeechTool := nil;
    Conn.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('======================================');
    Writeln(' Gemini TTS via ChatTools Demo        ');
    Writeln('======================================');
    Writeln;
    RunDemo;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
