# CLAUDE.md — AiMaker.ChatTools

## Propósito

Este repositorio contiene implementaciones concretas de las interfaces ChatTools de MakerAI.
Cada unidad implementa una interfaz de `uMakerAi.Chat.Tools` (IAiWebSearchTool,
IAiSpeechTool, IAiVisionTool, IAiImageTool, IAiVideoTool, IAiPdfTool) usando un
servicio externo específico.

**Repositorio base requerido:** MakerAI (https://github.com/gustavoeenriquez/MakerAi)
**Relación:** Este paquete DEPENDE de MakerAI pero NO modifica su código.

---

## Estructura del repositorio

```
AiMaker.ChatTools/
  Source/
    Web/        — Búsqueda web (5 servicios)
    Speech/     — TTS y STT (8 servicios)
    Vision/     — Descripción de imágenes (3 servicios)
    Image/      — Generación de imágenes (4 servicios)
    Video/      — Generación de video (5 servicios)
    Pdf/        — Parsing de documentos PDF (4 servicios)
    Packages/
      uMakerAi.ChatTools.dpk    — Paquete Delphi runtime (29 units)
      uMakerAi.ChatTools.dproj  — Proyecto del paquete
  Demos/
    <Servicio>/
      01-DirectCall/   — Uso directo sin TAiChatConnection
      02-ChatTools/    — Uso via bridge automático de ChatTools
  CLAUDE.md
```

---

## Instalación

### Prerrequisitos
1. MakerAI instalado y compilado (paquete `MakerAI.bpl` disponible)
2. Rutas de MakerAI configuradas en el Library Path de Delphi

### Compilar el paquete
1. Abrir `Source/Packages/uMakerAi.ChatTools.dproj` en Delphi
2. Build → el paquete genera `uMakerAi.ChatTools.bpl`
3. Opcional: instalar en el IDE (Component > Install Packages)

### Sin paquete (solo fuente)
Agregar el subdirectorio correspondiente al Library Path de Delphi.
Las demos incluyen las rutas necesarias en su `.dproj`.

---

## Herramientas disponibles

### Web Search (`Source/Web/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiTavilyWebSearchTool` | `IAiWebSearchTool` | `uMakerAi.ChatTools.Tavily.pas` | Tavily AI Search | `TAVILY_API_KEY` |
| `TAiBraveSearchTool` | `IAiWebSearchTool` | `uMakerAi.ChatTools.BraveSearch.pas` | Brave Search | `BRAVE_API_KEY` |
| `TAiSerpApiSearchTool` | `IAiWebSearchTool` | `uMakerAi.ChatTools.SerpApi.pas` | SerpApi (Google) | `SERPAPI_API_KEY` |
| `TAiExaSearchTool` | `IAiWebSearchTool` | `uMakerAi.ChatTools.Exa.pas` | Exa Search | `EXA_API_KEY` |
| `TAiPerplexitySonarTool` | `IAiWebSearchTool` | `uMakerAi.ChatTools.PerplexitySonar.pas` | Perplexity Sonar | `PERPLEXITY_API_KEY` |

### Speech — TTS y STT (`Source/Speech/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiOpenAISpeechTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.OpenAISpeech.pas` | OpenAI Whisper + TTS | `OPENAI_API_KEY` |
| `TAiGeminiSpeechTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.GeminiSpeech.pas` | Gemini TTS + STT | `GEMINI_API_KEY` |
| `TAiClaudeSpeechTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.ClaudeSpeech.pas` | Claude STT (via messages) | `CLAUDE_API_KEY` |
| `TAiElevenLabsTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.ElevenLabs.pas` | ElevenLabs TTS + Scribe STT | `ELEVENLABS_API_KEY` |
| `TAiAssemblyAITool` | `IAiSpeechTool` | `uMakerAi.ChatTools.AssemblyAI.pas` | AssemblyAI STT | `ASSEMBLYAI_API_KEY` |
| `TAiDeepgramTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.Deepgram.pas` | Deepgram Nova-3 STT | `DEEPGRAM_API_KEY` |
| `TAiCartesiaTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.Cartesia.pas` | Cartesia TTS | `CARTESIA_API_KEY` |
| `TAiFishAudioTool` | `IAiSpeechTool` | `uMakerAi.ChatTools.FishAudio.pas` | Fish Audio TTS | `FISHAUDIO_API_KEY` |

### Vision (`Source/Vision/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiOpenAIVisionTool` | `IAiVisionTool` | `uMakerAi.ChatTools.OpenAIVision.pas` | OpenAI GPT-4o Vision | `OPENAI_API_KEY` |
| `TAiGeminiVisionTool` | `IAiVisionTool` | `uMakerAi.ChatTools.GeminiVision.pas` | Gemini Vision | `GEMINI_API_KEY` |
| `TAiClaudeVisionTool` | `IAiVisionTool` | `uMakerAi.ChatTools.ClaudeVision.pas` | Claude Vision | `CLAUDE_API_KEY` |

### Image Generation (`Source/Image/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiFalAiImageTool` | `IAiImageTool` | `uMakerAi.ChatTools.FalAi.pas` | fal.ai (queue async) | `FALAI_API_KEY` |
| `TAiIdeogramImageTool` | `IAiImageTool` | `uMakerAi.ChatTools.Ideogram.pas` | Ideogram v3 | `IDEOGRAM_API_KEY` |
| `TAiReplicateImageTool` | `IAiImageTool` | `uMakerAi.ChatTools.Replicate.pas` | Replicate (prediction async) | `REPLICATE_API_KEY` |
| `TAiStabilityAIImageTool` | `IAiImageTool` | `uMakerAi.ChatTools.StabilityAI.pas` | Stability AI (síncrono) | `STABILITYAI_API_KEY` |

### Video Generation (`Source/Video/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiGeminiVideoTool` | `IAiVideoTool` | `uMakerAi.ChatTools.GeminiVideo.pas` | Gemini Veo (LRO pattern) | `GEMINI_API_KEY` |
| `TAiOpenAIVideoTool` | `IAiVideoTool` | `uMakerAi.ChatTools.OpenAIVideo.pas` | OpenAI Sora (async poll) | `OPENAI_API_KEY` |
| `TAiKlingAIVideoTool` | `IAiVideoTool` | `uMakerAi.ChatTools.KlingAI.pas` | Kling AI (JWT HMAC-SHA256) | `KLINGAI_ACCESS_KEY` + `KLINGAI_SECRET_KEY` |
| `TAiRunwayMLVideoTool` | `IAiVideoTool` | `uMakerAi.ChatTools.RunwayML.pas` | Runway ML Gen-3/4 | `RUNWAYML_API_KEY` |
| `TAiDIDVideoTool` | `IAiVideoTool` | `uMakerAi.ChatTools.DID.pas` | D-ID (avatares hablantes) | `DID_API_KEY` |

### PDF Parsing (`Source/Pdf/`)

| Clase | Interfaz | Archivo | Servicio | API Key env var |
|---|---|---|---|---|
| `TAiLlamaParseDocTool` | `IAiPdfTool` | `uMakerAi.ChatTools.LlamaParse.pas` | LlamaParse (async poll) | `LLAMAPARSE_API_KEY` |
| `TAiMistralOcrTool` | `IAiPdfTool` | `uMakerAi.ChatTools.MistralOcr.pas` | Mistral OCR (síncrono) | `MISTRAL_API_KEY` |
| `TAiReductoPdfTool` | `IAiPdfTool` | `uMakerAi.ChatTools.Reducto.pas` | Reducto (síncrono o async) | `REDUCTO_API_KEY` |
| `TAiUnstructuredTool` | `IAiPdfTool` | `uMakerAi.ChatTools.Unstructured.pas` | Unstructured API | `UNSTRUCTURED_API_KEY` |

---

## Cómo agregar una nueva herramienta

1. Crear `Source/<categoria>/uMakerAi.ChatTools.<Servicio>.pas`
2. La clase hereda de la base correcta según la interfaz a implementar:

| Interfaz | Clase base | Método a implementar |
|---|---|---|
| `IAiWebSearchTool` | `TAiWebSearchToolBase` | `ExecuteSearch` |
| `IAiSpeechTool` | `TAiSpeechToolBase` | `ExecuteTranscription`, `ExecuteSpeechGeneration` |
| `IAiVisionTool` | `TAiVisionToolBase` | `ExecuteImageDescription` |
| `IAiImageTool` | `TAiImageToolBase` | `ExecuteImageGeneration` |
| `IAiVideoTool` | `TAiVideoToolBase` | `ExecuteVideoGeneration` |
| `IAiPdfTool` | `TAiPdfToolBase` | `ExecutePdfAnalysis` |

3. Patrón de implementación (igual para todos):

```pascal
procedure TMiHerramienta.ExecuteSearch(const AQuery: String;
  ResMsg, AskMsg: TAiChatMessage);
begin
  ReportState(acsConnecting, 'Conectando a MiServicio...');
  try
    // ... llamada HTTP al servicio ...
    ResMsg.Prompt := resultado;
    ReportDataEnd(ResMsg, 'assistant', resultado);
  except
    on E: Exception do
    begin
      ReportError(E.Message, E);
      ResMsg.Prompt := '';
    end;
  end;
end;
```

4. Agregar al `uMakerAi.ChatTools.dpk` en la sección `contains`
5. Crear demos `01-DirectCall` y `02-ChatTools` en `Demos/<Servicio>/`

---

## Convenciones de código

- Idioma de comentarios: **español** (consistente con MakerAI)
- Nombres de unidades: `uMakerAi.ChatTools.<Servicio>.pas`
- Nombres de clases: `TAi<Servicio><TipoTool>Tool` (p.ej. `TAiTavilyWebSearchTool`)
- API keys: siempre con default `'@<SERVICIO>_API_KEY'` en el constructor
- Resolución de env vars: `if FApiKey.StartsWith('@') then GetEnvironmentVariable(...)`

### Notas de autenticación especial

| Servicio | Mecanismo |
|---|---|
| **KlingAI** | JWT firmado HMAC-SHA256 con `AccessKey` + `SecretKey`; expira en 30 s |
| **D-ID** | Basic Auth con formato `key:` (password vacío) |
| **Runway ML** | Header `X-Runway-Version: 2024-11-06` **obligatorio** |
| **Unstructured** | Header personalizado `unstructured-api-key` (no `Authorization`) |
| **Cartesia** | `output_format` es un **objeto** anidado (no string) |
| **Claude Vision** | Content array: **imagen primero**, texto después (orden crítico) |

---

## Rutas relativas (referencia para .dproj)

Desde `Demos/<Servicio>/01-DirectCall/` o `02-ChatTools/`:

| Directorio | Ruta relativa |
|---|---|
| MakerAI Source/Core | `..\..\..\..\AiMaker\Source\Core` |
| MakerAI Source/Chat | `..\..\..\..\AiMaker\Source\Chat` |
| MakerAI Source/Tools | `..\..\..\..\AiMaker\Source\Tools` |
| MakerAI Source/Agents | `..\..\..\..\AiMaker\Source\Agents` |
| MakerAI Source/MCPClient | `..\..\..\..\AiMaker\Source\MCPClient` |
| MakerAI Source/MCPServer | `..\..\..\..\AiMaker\Source\MCPServer` |
| MakerAI Source/Utils | `..\..\..\..\AiMaker\Source\Utils` |
| MakerAI Source/Design | `..\..\..\..\AiMaker\Source\Design` |
| ChatTools Source/Web | `..\..\..\Source\Web` |
| ChatTools Source/Speech | `..\..\..\Source\Speech` |
| ChatTools Source/Vision | `..\..\..\Source\Vision` |
| ChatTools Source/Image | `..\..\..\Source\Image` |
| ChatTools Source/Video | `..\..\..\Source\Video` |
| ChatTools Source/Pdf | `..\..\..\Source\Pdf` |

---

## Variables de entorno requeridas por demo

| Demo | Variables necesarias |
|---|---|
| Tavily 01/02 | `TAVILY_API_KEY` |
| BraveSearch 01/02 | `BRAVE_API_KEY` |
| SerpApi 01/02 | `SERPAPI_API_KEY` |
| Exa 01/02 | `EXA_API_KEY` |
| PerplexitySonar 01/02 | `PERPLEXITY_API_KEY` |
| OpenAISpeech 01/02 | `OPENAI_API_KEY` |
| GeminiSpeech 01/02 | `GEMINI_API_KEY` |
| ClaudeSpeech 01/02 | `CLAUDE_API_KEY` |
| ElevenLabs 01/02 | `ELEVENLABS_API_KEY` |
| AssemblyAI 01/02 | `ASSEMBLYAI_API_KEY` |
| Deepgram 01/02 | `DEEPGRAM_API_KEY` |
| Cartesia 01/02 | `CARTESIA_API_KEY` |
| FishAudio 01/02 | `FISHAUDIO_API_KEY` |
| OpenAIVision 01/02 | `OPENAI_API_KEY` |
| GeminiVision 01/02 | `GEMINI_API_KEY` |
| ClaudeVision 01/02 | `CLAUDE_API_KEY` |
| FalAi 01/02 | `FALAI_API_KEY` |
| Ideogram 01/02 | `IDEOGRAM_API_KEY` |
| Replicate 01/02 | `REPLICATE_API_KEY` |
| StabilityAI 01/02 | `STABILITYAI_API_KEY` |
| GeminiVideo 01/02 | `GEMINI_API_KEY` |
| OpenAIVideo 01/02 | `OPENAI_API_KEY` |
| KlingAI 01/02 | `KLINGAI_ACCESS_KEY` + `KLINGAI_SECRET_KEY` |
| RunwayML 01/02 | `RUNWAYML_API_KEY` |
| DID 01/02 | `DID_API_KEY` |
| LlamaParse 01/02 | `LLAMAPARSE_API_KEY` |
| MistralOcr 01/02 | `MISTRAL_API_KEY` |
| Reducto 01/02 | `REDUCTO_API_KEY` |
| Unstructured 01/02 | `UNSTRUCTURED_API_KEY` |

Los demos 02-ChatTools también requieren la key del driver LLM usado
(p.ej. `CLAUDE_API_KEY` si el driver es `'Claude'`).
