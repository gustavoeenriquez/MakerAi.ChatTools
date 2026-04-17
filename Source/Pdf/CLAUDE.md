# CLAUDE.md — PDF Tools

## Herramientas de análisis de PDF en AiMaker.ChatTools

Este módulo contiene 5 implementaciones de `IAiPdfTool`:

1. **TAiNativePdfTool** — 100% Delphi, sin dependencias externas
2. **TAiLlamaParseDocTool** — LlamaParse (async polling)
3. **TAiMistralOcrTool** — Mistral OCR API (síncrono)
4. **TAiReductoPdfTool** — Reducto (síncrono o async)
5. **TAiUnstructuredTool** — Unstructured API

---

## TAiNativePdfTool — Análisis PDF 100% Delphi

### Característica principal

**Estrategia "texto primero":** 
- Abre el PDF localmente sin dependencias externas (biblioteca PDF pura Delphi)
- Extrae texto directo de páginas que lo contienen
- Renderiza páginas de imagen/escaneadas a PNG vía Skia
- Pasa imágenes al TAiChat configurado para análisis con visión

No requiere llamadas HTTP a servicios OCR/parsing — todo es local.

### Requisitos

- Biblioteca PDF Delphi: `E:\Copilot\delphi-libraries\pdf\`
- Skia4Delphi (FMX/System.Skia, ya incluido en Delphi 12+)
- Para análisis de imágenes: TAiChat con `cap_Image` asignado (p.ej. GPT-4o, Claude, Gemini)

### Propiedades

```pascal
property VisionChat: TAiChat              // Chat para análisis de imágenes (nil = omitir imágenes)
property Prompt: string                   // Prompt enviado con cada imagen de página
property DPI: Integer                     // Resolución de rendering (default 150)
property MinTextLength: Integer           // Mínimo de chars para considerar "tiene texto" (default 10)
property OnProgress: TOnNativePdfProgress // Callback por página procesada
```

### Algoritmo

Para cada página `i` de 0 a `PageCount - 1`:

1. **Intenta extraer texto directo:**
   ```
   TPDFTextExtractor.ExtractPage(i).PlainText
   ```

2. **Si tiene texto (length >= MinTextLength):**
   - Agregar a resultado final (sin llamada a IA)

3. **Si NO tiene texto (imagen/escaneada):**
   - Renderizar a PNG vía `TPDFSkiaRenderer`
   - Si `VisionChat` está asignado:
     - Crear `TAiMediaFile` temporal
     - Llamar `VisionChat.AddMessageAndRun(Prompt, 'user', [PageImage])`
     - Agregar resultado a texto final
   - Si `VisionChat` NO está asignado:
     - Agregar nota "(Sin VisionChat para procesar página imagen)"

4. **Resultado final:**
   - Concatenar todas las páginas procesadas
   - Poblar `aMediaFile.Transcription`
   - Llamar `ReportDataEnd` y `ReportState(acsFinished)`

### Threading

- Si `IsAsync=True` → ejecución directa en hilo background
- Si `IsAsync=False` → wrapped en `TTask.Run`

Dentro del hilo, llamadas a `VisionChat.AddMessageAndRun` son **sincrónicas** (modo `Asynchronous:=False` temporal) para evitar anidamiento de tasks.

### Diferencia vs otras herramientas PDF

| Herramienta | Tipo | Ventaja | Desventaja |
|---|---|---|---|
| **TAiNativePdfTool** | Local | Sin API key, sin latencia HTTP, control total | Requiere Skia4Delphi |
| TAiLlamaParseDocTool | Cloud | OCR avanzado, LLM integrado | API key, async polling, costo |
| TAiMistralOcrTool | Cloud | API dedicada OCR | API key, solo OCR (no contenido estructurado) |
| TAiReductoPdfTool | Cloud | Flexible (sync/async) | API key, costo |
| TAiUnstructuredTool | Cloud | Manejo de múltiples formatos | API key, no OCR de escaneos |

**Recomendación:** TAiNativePdfTool para PDFs simples con texto. LlamaParse/Reducto para PDFs complejos con layouts estructurados.

### Ejemplo de uso mínimo (DirectCall)

```pascal
var
  PdfTool: TAiNativePdfTool;
begin
  PdfTool := TAiNativePdfTool.Create(nil);
  try
    PdfTool.DPI := 150;
    PdfTool.MinTextLength := 10;
    var Text := PdfTool.ExtractText('documento.pdf');
    WriteLn(Text);
  finally
    PdfTool.Free;
  end;
end;
```

### Ejemplo con TAiChatConnection (ChatTools pattern)

```pascal
var
  AiConnection: TAiChatConnection;
  PdfTool: TAiNativePdfTool;
  Media: TAiMediaFile;
begin
  AiConnection := TAiChatConnection.Create(nil);
  PdfTool := TAiNativePdfTool.Create(nil);
  try
    AiConnection.DriverName := 'Claude';
    AiConnection.Model := 'claude-3-5-sonnet-20241022';
    AiConnection.ApiKey := '@CLAUDE_API_KEY';

    PdfTool.VisionChat := AiConnection;  // ← asignar para análisis de imágenes
    PdfTool.DPI := 150;
    PdfTool.Prompt := 'Extrae todo el texto e información de esta página.';

    AiConnection.PdfTool := PdfTool;

    Media := TAiMediaFile.Create;
    try
      Media.LoadFromFile('documento.pdf');
      var Result := AiConnection.AddMessageAndRun(
        'Analiza este PDF',
        'user',
        [Media]
      );
      WriteLn(Result);
    finally
      Media.Free;
    end;
  finally
    PdfTool.Free;
    AiConnection.Free;
  end;
end;
```

---

## Flujo de integración en TAiChat.RunNew

Cuando `RunNew` procesa un archivo PDF:

1. **FASE 1:** Detecta `cap_Pdf` en el gap (`SessionCaps - ModelCaps`)
2. Llama `InternalRunPDFDescription(aMediaFile, ResMsg, AskMsg)`
3. Si está asignado `ChatTools.PdfTool`:
   - Llama `IAiPdfTool.ExecutePdfAnalysis(aMediaFile, ResMsg, AskMsg)`
   - TAiNativePdfTool procesa página por página
   - Resultado almacenado en `aMediaFile.Transcription`
4. **FASE 2/3:** El texto extraído se pasa al modelo para análisis final

---

## Notas técnicas

### Memory management
- `TPDFDocument` y `TPDFTextExtractor` deben ser liberados correctamente
- `TPDFSkiaRenderer` no es thread-safe — se recrea para cada página
- `ISkImage` se libera automáticamente al salir del scope

### PDF encrypted
- `TPDFDocument` auto-intenta decodificar con password vacío
- Si falla y es encrypted → fallará con excepción
- No hay soporte para PDFs protegidos con contraseña

### Performance
- Extracción de texto: muy rápido (~1ms/página)
- Rendering Skia: ~50-200ms/página (depende de DPI y complejidad)
- Llamadas a VisionChat: ~1-5s/página (depende del provider)

Para PDFs largos, considerar:
- Procesar solo primeras N páginas
- Aumentar `MinTextLength` para omitir páginas con poco contenido

---

## Archivos

| Archivo | Propósito |
|---|---|
| `uMakerAi.ChatTools.NativePdf.pas` | Implementación TAiNativePdfTool |
| `..\Demos\NativePdf\01-DirectCall\` | Demo de uso mínimo |
| `..\Demos\NativePdf\02-ChatTools\` | Demo integrado con ChatTools |
