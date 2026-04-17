program NativePdfChatToolsDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.AiConnection,
  uMakerAi.ChatTools.NativePdf;

var
  AiConnection: TAiChatConnection;
  PdfTool: TAiNativePdfTool;
  PdfPath: string;
  Media: TAiMediaFile;

begin
  try
    WriteLn('=== TAiNativePdfTool with ChatTools Integration ===');
    WriteLn('');

    // Crear los componentes
    AiConnection := TAiChatConnection.Create(nil);
    PdfTool := TAiNativePdfTool.Create(nil);

    try
      // Configurar el chat para visión (driver + model con cap_Image)
      AiConnection.DriverName := 'Claude';  // o 'OpenAI', etc.
      AiConnection.Model := 'claude-3-5-sonnet-20241022';
      AiConnection.ApiKey := '@CLAUDE_API_KEY';  // resuelve desde env var

      // Configurar la herramienta PDF
      PdfTool.VisionChat := AiConnection;  // asignar el chat para procesar imágenes
      PdfTool.DPI := 150;
      PdfTool.MinTextLength := 10;
      PdfTool.Prompt := 'Extrae todo el texto e información visible de esta página del PDF.';
      PdfTool.OnProgress := procedure(Sender: TObject; CurrentPage, TotalPages: Integer;
                                       const StatusMsg: string)
      begin
        WriteLn(Format('  Página %d/%d: %s', [CurrentPage, TotalPages, StatusMsg]));
      end;

      // Asignar la herramienta al chat
      AiConnection.PdfTool := PdfTool;

      // Procesar un PDF
      PdfPath := 'C:\Temp\ejemplo.pdf';

      if FileExists(PdfPath) then
      begin
        WriteLn('Procesando PDF: ' + PdfPath);
        WriteLn('');
        WriteLn('Configuración:');
        WriteLn('  Driver: ' + AiConnection.DriverName);
        WriteLn('  Modelo: ' + AiConnection.Model);
        WriteLn('  DPI: ' + IntToStr(PdfTool.DPI));
        WriteLn('  Min Text Length: ' + IntToStr(PdfTool.MinTextLength));
        WriteLn('');
        WriteLn('Procesando...');
        WriteLn('');

        // Cargar el PDF en una TAiMediaFile
        Media := TAiMediaFile.Create;
        try
          Media.LoadFromFile(PdfPath);

          // Disparar el análisis del PDF via chat (FASE 1 en RunNew)
          // Esto llamará automáticamente a PdfTool.ExecutePdfAnalysis
          AiConnection.Asynchronous := False;
          var LResult := AiConnection.AddMessageAndRun(
            'Analiza este PDF y extrae la información clave.',
            'user',
            [Media]
          );

          WriteLn('');
          WriteLn('Resultado:');
          WriteLn('-----------------------------------------');
          WriteLn(LResult);
          WriteLn('-----------------------------------------');

        finally
          Media.Free;
        end;
      end
      else
      begin
        WriteLn('ERROR: Archivo no encontrado: ' + PdfPath);
        WriteLn('Para usar este demo:');
        WriteLn('  1. Coloca un PDF en C:\Temp\ejemplo.pdf');
        WriteLn('  2. Configura la env var CLAUDE_API_KEY con tu API key de Claude');
        WriteLn('     (o usa otro driver como OpenAI con OPENAI_API_KEY)');
        WriteLn('');
        WriteLn('Cómo funciona:');
        WriteLn('  - El PDF se procesa página por página');
        WriteLn('  - Páginas con texto se extraen directamente (sin IA)');
        WriteLn('  - Páginas escaneadas se renderizaron a PNG y se pasarán');
        WriteLn('    al VisionChat (GPT-4o, Claude, etc.)');
      end;

    finally
      PdfTool.Free;
      AiConnection.Free;
    end;

  except
    on E: Exception do
      WriteLn('ERROR: ' + E.Message);
  end;

  WriteLn('');
  WriteLn('Presione Enter para salir...');
  ReadLn;
end.
