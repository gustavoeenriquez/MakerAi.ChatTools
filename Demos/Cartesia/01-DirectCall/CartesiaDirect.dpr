program CartesiaDirect;

// Demo 01 - Llamado directo a TAiCartesiaTTSTool
// Cartesia esta optimizado para baja latencia.
// REQUISITO: CARTESIA_API_KEY + un VoiceId valido de Cartesia

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Cartesia;

const
  OUTPUT_AUDIO = 'cartesia_output.mp3';
  // Obtener VoiceIds en: https://play.cartesia.ai/voice-library
  // Ejemplo de voz en español (reemplazar con un ID real)
  VOICE_ID_ES  = '';  // <- Asignar un VoiceId valido de Cartesia

procedure RunTTS;
var
  Tool  : TAiCartesiaTTSTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  if VOICE_ID_ES.IsEmpty then
  begin
    Writeln('OMITIDO: asignar VOICE_ID_ES en el codigo fuente.');
    Writeln('Ver voces en: https://play.cartesia.ai/voice-library');
    Exit;
  end;

  Writeln('--- Cartesia TTS (baja latencia) ---');
  Tool   := TAiCartesiaTTSTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey     := '@CARTESIA_API_KEY';
    Tool.ModelId    := 'sonic-2';
    Tool.VoiceId    := VOICE_ID_ES;
    Tool.Language   := 'es';
    Tool.Container  := 'mp3';
    Tool.Encoding   := 'mp3';
    Tool.SampleRate := 44100;

    AskMsg.Prompt := 'Buenos dias. Soy Cartesia Sonic, un motor de voz de alta calidad ' +
                     'optimizado para aplicaciones en tiempo real.';

    Writeln('Texto: ', AskMsg.Prompt);
    Write('Generando audio (baja latencia)... ');
    Tool.ExecuteSpeechGeneration(AskMsg.Prompt, ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
    begin
      ResMsg.MediaFiles[0].Stream.SaveToFile(OUTPUT_AUDIO);
      Writeln('OK');
      Writeln('Audio guardado en: ', OUTPUT_AUDIO);
    end
    else
      Writeln('No se genero audio');
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Cartesia TTS Direct Demo               ');
    Writeln('========================================');
    Writeln;
    RunTTS;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
