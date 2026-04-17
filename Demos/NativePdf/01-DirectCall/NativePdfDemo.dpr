program NativePdfDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.ChatTools.NativePdf;

var
  PdfTool: TAiNativePdfTool;
  PdfPath: string;
  Result: string;

begin
  try
    WriteLn('=== TAiNativePdfTool Demo (DirectCall) ===');
    WriteLn('');

    // Crear instancia del componente
    PdfTool := TAiNativePdfTool.Create(nil);
    try
      // Configurar propiedades
      PdfTool.DPI := 150;
      PdfTool.MinTextLength := 10;
      PdfTool.Prompt := 'Extrae todo el texto e información de esta página del PDF.';

      // Ejemplo 1: Procesar un PDF con ExtractText (requiere VisionChat para páginas imagen)
      PdfPath := 'C:\Temp\ejemplo.pdf';

      if FileExists(PdfPath) then
      begin
        WriteLn('Procesando: ' + PdfPath);
        WriteLn('');

        // Sin VisionChat asignado — solo procesará páginas con texto directo
        WriteLn('Nota: Sin VisionChat asignado. Solo se procesarán páginas con texto extraíble.');
        WriteLn('');

        Result := PdfTool.ExtractText(PdfPath);

        WriteLn('Resultado:');
        WriteLn('-----------------------------------------');
        WriteLn(Result);
        WriteLn('-----------------------------------------');
      end
      else
      begin
        WriteLn('ERROR: Archivo no encontrado: ' + PdfPath);
        WriteLn('Para usar este demo, coloca un PDF en C:\Temp\ejemplo.pdf');
        WriteLn('');
        WriteLn('Ejemplo de configuración CON VisionChat:');
        WriteLn('');
        WriteLn('  AiConnection: TAiChatConnection;');
        WriteLn('  PdfTool: TAiNativePdfTool;');
        WriteLn('begin');
        WriteLn('  PdfTool.VisionChat := AiConnection;  // Asignar chat con cap_Image');
        WriteLn('  PdfTool.DPI := 150;');
        WriteLn('  PdfTool.Prompt := ''Extrae todo...'';');
        WriteLn('  Result := PdfTool.ExtractText(''documento.pdf'');');
        WriteLn('end;');
      end;

    finally
      PdfTool.Free;
    end;

  except
    on E: Exception do
      WriteLn('ERROR: ' + E.Message);
  end;

  WriteLn('');
  WriteLn('Presione Enter para salir...');
  ReadLn;
end.
