program FishAudioDirect;

// Demo 01 - Llamado directo a TAiFishAudioTTSTool
// Fish Audio: TTS con clonación de voz open-source.
// REQUISITO: FISHAUDIO_API_KEY + ReferenceId de modelo de voz

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, System.Classes,
  uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.FishAudio;

const
  OUTPUT_AUDIO = 'fishaudio_output.mp3';
  // Buscar modelos en: https://fish.audio/model/
  // Ejemplo de modelo en español (reemplazar con un ID real)
  REFERENCE_ID = '';  // <- Asignar un ReferenceId valido de Fish Audio

procedure RunTTS;
var
  Tool  : TAiFishAudioTTSTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  if REFERENCE_ID.IsEmpty then
  begin
    Writeln('OMITIDO: asignar REFERENCE_ID en el codigo fuente.');
    Writeln('Buscar modelos en: https://fish.audio/model/');
    Exit;
  end;

  Writeln('--- Fish Audio TTS (clonación de voz) ---');
  Tool   := TAiFishAudioTTSTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey      := '@FISHAUDIO_API_KEY';
    Tool.ReferenceId := REFERENCE_ID;
    Tool.Format      := 'mp3';
    Tool.Mp3Bitrate  := 128;
    Tool.Normalize   := True;
    Tool.Latency     := 'normal';

    AskMsg.Prompt := 'Bienvenido a Fish Audio, una plataforma de clonación de voz ' +
                     'con tecnologia open-source y alta calidad.';

    Writeln('Texto: ', AskMsg.Prompt);
    Write('Generando audio... ');
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
    Writeln(' Fish Audio TTS Direct Demo             ');
    Writeln('========================================');
    Writeln;
    RunTTS;
  except
    on E: Exception do begin Writeln('ERROR: ', E.Message); ExitCode := 1; end;
  end;
  Writeln; Write('Presiona Enter...'); Readln;
end.
