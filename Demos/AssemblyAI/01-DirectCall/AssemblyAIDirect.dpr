program AssemblyAIDirect;

// Demo 01 - Llamado directo a TAiAssemblyAISTTTool
//
// Muestra el uso de AssemblyAI sin TAiChatConnection.
// Ejecuta los 3 pasos manualmente: upload -> submit -> polling.
//
// REQUISITOS:
//   1. Variable de entorno ASSEMBLYAI_API_KEY
//   2. Un archivo de audio en TEST_AUDIO_FILE (cambiar la ruta)
//
// NOTA: AssemblyAI es asíncrono — el polling puede tomar 10-60 segundos
// dependiendo del tamaño del audio y la carga del servidor.

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools,
  uMakerAi.ChatTools.AssemblyAI;

const
  // Cambiar esta ruta a un archivo de audio real para probar
  TEST_AUDIO_FILE = 'C:\test_audio.mp3';

procedure RunBasicTranscription;
var
  Tool   : TAiAssemblyAISTTTool;
  AskMsg : TAiChatMessage;
  ResMsg : TAiChatMessage;
  Media  : TAiMediaFile;
begin
  Writeln('--- Transcripcion basica (model=best) ---');

  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: archivo de audio no encontrado: ', TEST_AUDIO_FILE);
    Writeln('Modifica la constante TEST_AUDIO_FILE en el codigo fuente.');
    Exit;
  end;

  Tool   := TAiAssemblyAISTTTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey       := '@ASSEMBLYAI_API_KEY';
    Tool.Model        := 'best';
    Tool.LanguageCode := 'es';

    Media.LoadFromFile(TEST_AUDIO_FILE);

    Writeln('Archivo : ', TEST_AUDIO_FILE);
    Writeln('Paso 1/3: Subiendo audio...');
    Writeln('Paso 2/3: Enviando solicitud...');
    Writeln('Paso 3/3: Esperando transcripción (puede tardar 15-60 seg)...');
    Writeln;

    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);

    Writeln('=== Transcripcion ===');
    Writeln(ResMsg.Prompt);
  finally
    Media.Free;
    ResMsg.Free;
    AskMsg.Free;
    Tool.Free;
  end;
end;

procedure RunWithSpeakerLabels;
var
  Tool   : TAiAssemblyAISTTTool;
  AskMsg : TAiChatMessage;
  ResMsg : TAiChatMessage;
  Media  : TAiMediaFile;
begin
  Writeln('--- Transcripcion con identificación de hablantes ---');

  if not FileExists(TEST_AUDIO_FILE) then
  begin
    Writeln('OMITIDO: archivo de audio no encontrado.');
    Exit;
  end;

  Tool   := TAiAssemblyAISTTTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  Media  := TAiMediaFile.Create(nil);
  try
    Tool.ApiKey        := '@ASSEMBLYAI_API_KEY';
    Tool.Model         := 'best';
    Tool.LanguageCode  := 'es';
    Tool.SpeakerLabels := True;  // identifica Speaker A, Speaker B...

    Media.LoadFromFile(TEST_AUDIO_FILE);

    Writeln('Procesando con diarización...');
    Writeln;

    Tool.ExecuteTranscription(Media, ResMsg, AskMsg);

    Writeln('=== Transcripcion con hablantes ===');
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
    Writeln(' AssemblyAI STT Direct Demo             ');
    Writeln('========================================');
    Writeln;
    RunBasicTranscription;
    Writeln;
    Writeln('========================================');
    Writeln;
    RunWithSpeakerLabels;
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
