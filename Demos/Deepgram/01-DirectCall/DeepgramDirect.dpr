program DeepgramDirect;

// Demo 01 - Llamado directo a TAiDeepgramSTTTool
//
// Deepgram es síncrono: una sola llamada HTTP, respuesta inmediata.
// El audio se envia como binario directo en el body (no JSON, no multipart).
//
// REQUISITOS:
//   1. Variable de entorno DEEPGRAM_API_KEY
//   2. Un archivo de audio en TEST_AUDIO_FILE

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.Deepgram;

const
  TEST_AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunNova3Spanish;
var
  Tool  : TAiDeepgramSTTTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- nova-3 en espanol con SmartFormat ---');

  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_AUDIO_FILE, ' no encontrado.');
    Exit;
  end;

  Tool   := TAiDeepgramSTTTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey      := '@DEEPGRAM_API_KEY';
    Tool.Model       := 'nova-3';
    Tool.Language    := 'es';
    Tool.SmartFormat := True;   // formatea números, fechas, monedas
    Tool.Punctuate   := True;

    Media.LoadFromFile(TEST_AUDIO_FILE);

    Writeln('Archivo: ', TEST_AUDIO_FILE);
    Write('Transcribiendo... ');
    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln(ResMsg.Prompt);
  finally
    Media.Free;
    ResMsg.Free;
    AskMsg.Free;
    Tool.Free;
  end;
end;

procedure RunWithAutoDetect;
var
  Tool  : TAiDeepgramSTTTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
  Media : TAiMediaFile;
begin
  Writeln('--- Deteccion automatica de idioma ---');

  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: ', TEST_AUDIO_FILE, ' no encontrado.');
    Exit;
  end;

  Tool   := TAiDeepgramSTTTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey         := '@DEEPGRAM_API_KEY';
    Tool.Model          := 'nova-3';
    Tool.DetectLanguage := True;  // ignora Tool.Language
    Tool.SmartFormat    := True;

    Media.LoadFromFile(TEST_AUDIO_FILE);

    Write('Transcribiendo (auto-detect idioma)... ');
    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);
    Writeln('OK');
    Writeln;
    Writeln(ResMsg.Prompt);
  finally
    Media.Free;
    ResMsg.Free;
    AskMsg.Free;
    Tool.Free;
  end;
end;

begin
  try
    Writeln('========================================');
    Writeln(' Deepgram STT Direct Demo               ');
    Writeln('========================================');
    Writeln;
    RunNova3Spanish;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunWithAutoDetect;
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
