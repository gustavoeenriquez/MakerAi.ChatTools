# MakerAI ChatTools

Companion package for [MakerAI](https://github.com/gustavoeenriquez/MakerAi) that provides
concrete implementations of the ChatTools bridge interfaces (`IAiWebSearchTool`,
`IAiSpeechTool`, `IAiVisionTool`, `IAiImageTool`, `IAiVideoTool`, `IAiPdfTool`).

Each unit wraps a specific third-party API and plugs directly into `TAiChatConnection`
via the gap-analysis bridge: set `SessionCaps` to declare what capability you need,
assign the corresponding tool, and MakerAI routes the call automatically.

```pascal
Conn.Params.Values['ModelCaps']   := '[]';
Conn.Params.Values['SessionCaps'] := '[cap_WebSearch]';
Conn.WebSearchTool := TAiTavilyWebSearchTool.Create(nil);
// MakerAI detects the gap and calls Tavily before completions
```

---

## Requirements

- **Delphi** 11 Alexandria or later (10.4 Sydney minimum)
- **MakerAI** installed and compiled — [github.com/gustavoeenriquez/MakerAi](https://github.com/gustavoeenriquez/MakerAi)

---

## Installation

### Option A — Install as a package
1. Open `Source/Packages/uMakerAi.ChatTools.dproj` in Delphi
2. **Build** → generates `uMakerAi.ChatTools.bpl`
3. **Install** via Component > Install Packages

### Option B — Add source to Library Path
Add the specific `Source/<category>/` subfolder to Delphi's Library Path.
Each demo `.dproj` already includes the correct relative paths.

---

## Available Tools

### Web Search

| Class | Service | Env Var |
|---|---|---|
| `TAiTavilyWebSearchTool` | [Tavily AI Search](https://docs.tavily.com) | `TAVILY_API_KEY` |
| `TAiBraveSearchTool` | [Brave Search](https://api.search.brave.com) | `BRAVE_API_KEY` |
| `TAiSerpApiSearchTool` | [SerpApi (Google)](https://serpapi.com) | `SERPAPI_API_KEY` |
| `TAiExaSearchTool` | [Exa Search](https://exa.ai) | `EXA_API_KEY` |
| `TAiPerplexitySonarTool` | [Perplexity Sonar](https://docs.perplexity.ai) | `PERPLEXITY_API_KEY` |

### Speech — TTS & STT

| Class | Service | Env Var |
|---|---|---|
| `TAiOpenAISpeechTool` | OpenAI Whisper + TTS | `OPENAI_API_KEY` |
| `TAiGeminiSpeechTool` | Gemini TTS + STT | `GEMINI_API_KEY` |
| `TAiClaudeSpeechTool` | Claude STT (via messages API) | `CLAUDE_API_KEY` |
| `TAiElevenLabsTool` | [ElevenLabs](https://elevenlabs.io) TTS + Scribe STT | `ELEVENLABS_API_KEY` |
| `TAiAssemblyAITool` | [AssemblyAI](https://www.assemblyai.com) STT | `ASSEMBLYAI_API_KEY` |
| `TAiDeepgramTool` | [Deepgram](https://deepgram.com) Nova-3 STT | `DEEPGRAM_API_KEY` |
| `TAiCartesiaTool` | [Cartesia](https://cartesia.ai) TTS | `CARTESIA_API_KEY` |
| `TAiFishAudioTool` | [Fish Audio](https://fish.audio) TTS | `FISHAUDIO_API_KEY` |

### Vision

| Class | Service | Env Var |
|---|---|---|
| `TAiOpenAIVisionTool` | OpenAI GPT-4o Vision | `OPENAI_API_KEY` |
| `TAiGeminiVisionTool` | Gemini Vision | `GEMINI_API_KEY` |
| `TAiClaudeVisionTool` | Claude Vision | `CLAUDE_API_KEY` |

### Image Generation

| Class | Service | Env Var |
|---|---|---|
| `TAiFalAiImageTool` | [fal.ai](https://fal.ai) (queue async) | `FALAI_API_KEY` |
| `TAiIdeogramImageTool` | [Ideogram v3](https://ideogram.ai) | `IDEOGRAM_API_KEY` |
| `TAiReplicateImageTool` | [Replicate](https://replicate.com) (prediction async) | `REPLICATE_API_KEY` |
| `TAiStabilityAIImageTool` | [Stability AI](https://stability.ai) | `STABILITYAI_API_KEY` |

### Video Generation

| Class | Service | Env Var |
|---|---|---|
| `TAiGeminiVideoTool` | Gemini Veo (LRO pattern) | `GEMINI_API_KEY` |
| `TAiOpenAIVideoTool` | [OpenAI Sora](https://openai.com/sora) (async poll) | `OPENAI_API_KEY` |
| `TAiKlingAIVideoTool` | [Kling AI](https://klingai.com) (JWT auth) | `KLINGAI_ACCESS_KEY` + `KLINGAI_SECRET_KEY` |
| `TAiRunwayMLVideoTool` | [Runway ML](https://runwayml.com) Gen-3/4 | `RUNWAYML_API_KEY` |
| `TAiDIDVideoTool` | [D-ID](https://www.d-id.com) (talking avatars) | `DID_API_KEY` |

### PDF Parsing

| Class | Service | Env Var |
|---|---|---|
| `TAiLlamaParseDocTool` | [LlamaParse](https://docs.llamaindex.ai/en/stable/llama_cloud/llama_parse/) | `LLAMAPARSE_API_KEY` |
| `TAiMistralOcrTool` | Mistral OCR (synchronous) | `MISTRAL_API_KEY` |
| `TAiReductoPdfTool` | [Reducto](https://reducto.ai) | `REDUCTO_API_KEY` |
| `TAiUnstructuredTool` | [Unstructured](https://unstructured.io) | `UNSTRUCTURED_API_KEY` |

---

## Usage Pattern

### Direct call (without TAiChatConnection)

```pascal
uses uMakerAi.ChatTools.Tavily;

var
  Tool  : TAiTavilyWebSearchTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Tool   := TAiTavilyWebSearchTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey      := '@TAVILY_API_KEY';  // reads TAVILY_API_KEY env var
    Tool.MaxResults  := 5;
    AskMsg.Prompt    := 'best AI models 2025';
    Tool.ExecuteSearch(AskMsg.Prompt, ResMsg, AskMsg);
    Writeln(ResMsg.Prompt);
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;
```

### Automatic bridge via TAiChatConnection (gap analysis)

```pascal
uses uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
     uMakerAi.ChatTools.Tavily;

var
  Conn  : TAiChatConnection;
  Tavily: TAiTavilyWebSearchTool;
begin
  Tavily := TAiTavilyWebSearchTool.Create(nil);
  Conn   := TAiChatConnection.Create(nil);
  try
    Tavily.ApiKey := '@TAVILY_API_KEY';

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := Tavily;

    // MakerAI detects gap → calls Tavily → injects results → completions
    Writeln(Conn.AddMessageAndRun('What are the top AI models of 2025?', 'user', []));
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Tavily.Free;
  end;
end;
```

---

## Demos

Open `Demos/ChatToolsDemos.groupproj` in Delphi IDE to access all 58 demo projects.

Each service has two demos:
- **`01-DirectCall`** — standalone usage without TAiChatConnection
- **`02-ChatTools`** — full bridge integration with TAiChatConnection + gap analysis

---

## Adding a New Tool

1. Create `Source/<category>/uMakerAi.ChatTools.<Service>.pas`
2. Inherit from the correct base class:
   - `TAiWebSearchToolBase` → implement `ExecuteSearch`
   - `TAiSpeechToolBase` → implement `ExecuteTranscription` / `ExecuteSpeechGeneration`
   - `TAiVisionToolBase` → implement `ExecuteImageDescription`
   - `TAiImageToolBase` → implement `ExecuteImageGeneration`
   - `TAiVideoToolBase` → implement `ExecuteVideoGeneration`
   - `TAiPdfToolBase` → implement `ExecutePdfAnalysis`
3. Use `ReportState`, `ReportDataEnd`, `ReportError` for lifecycle callbacks
4. Add the unit to `Source/Packages/uMakerAi.ChatTools.dpk`
5. Create `Demos/<Service>/01-DirectCall/` and `02-ChatTools/` demos

---

## License

MIT License — Copyright (c) 2026 Gustavo Enríquez - CimaMaker

---

## Links

- MakerAI (core framework): https://github.com/gustavoeenriquez/MakerAi
- Official website: https://makerai.cimamaker.com
