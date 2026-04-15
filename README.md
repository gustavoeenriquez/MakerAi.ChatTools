# MakerAI ChatTools

> Companion package for [MakerAI](https://github.com/gustavoeenriquez/MakerAi) — 29 ready-to-use
> implementations of the ChatTools bridge interfaces for Delphi applications.

Each unit wraps a specific third-party AI API and plugs directly into `TAiChatConnection`
via MakerAI's **gap-analysis bridge**: set `SessionCaps` to declare what capability you need,
assign the corresponding tool, and MakerAI routes the call automatically — no changes to
your chat code.

```pascal
Conn.Params.Values['ModelCaps']   := '[]';
Conn.Params.Values['SessionCaps'] := '[cap_WebSearch]';
Conn.WebSearchTool := TAiTavilyWebSearchTool.Create(nil);
// RunNew detects the gap → calls Tavily → injects results → completions
```

---

## Requirements

- **Delphi** 11 Alexandria or later (10.4 Sydney minimum)
- **MakerAI** installed and compiled → [github.com/gustavoeenriquez/MakerAi](https://github.com/gustavoeenriquez/MakerAi)

---

## Installation

### Option A — Package (recommended)
1. Open `Source/Packages/uMakerAi.ChatTools.dproj` in Delphi
2. **Build** → generates `uMakerAi.ChatTools.bpl`
3. **Install** via Component > Install Packages

### Option B — Source only
Add the specific `Source/<category>/` folder to Delphi's Library Path.
Each demo `.dproj` already includes the correct relative paths.

---

## Available Tools

### Web Search

These tools implement `IAiWebSearchTool` — used when `SessionCaps` includes `cap_WebSearch`.  
Assign to `TAiChatConnection.WebSearchTool`.

| Class | Service | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|
| `TAiTavilyWebSearchTool` | **Tavily AI Search** — AI-optimized web search returning pre-processed results and a synthesized answer. Best for LLM RAG pipelines. | 1,000 req/month | From $20/month (4K req) | [app.tavily.com](https://app.tavily.com) |
| `TAiBraveSearchTool` | **Brave Search** — Independent search index (not Google). Privacy-focused. Supports language/country filtering. | 2,000 req/month | $3/1,000 queries | [api.search.brave.com](https://api.search.brave.com/app/keys) |
| `TAiSerpApiWebSearchTool` | **SerpApi** — Scrapes Google, Bing, YouTube and more. Returns structured JSON including answer boxes and knowledge panels. | 100 searches/month | From $50/month (5K) | [serpapi.com](https://serpapi.com/users/sign_up) |
| `TAiExaWebSearchTool` | **Exa** — Neural semantic search. Returns full page contents, not just snippets. Ideal for research agents that need rich text context. | 1,000 req/month | $0.25/1,000 searches + $0.01/content | [exa.ai](https://dashboard.exa.ai/login) |
| `TAiPerplexitySonarTool` | **Perplexity Sonar** — Uses Sonar LLMs to search and synthesize an answer with citations in a single API call. | No free tier | $5/1,000 req (sonar), $15/1,000 req (sonar-pro) | [perplexity.ai/settings/api](https://www.perplexity.ai/settings/api) |

**Key properties** (all tools): `ApiKey`, `MaxResults`/`NumResults`/`Count`.  
**Env var convention**: `TAVILY_API_KEY`, `BRAVE_API_KEY`, `SERPAPI_API_KEY`, `EXA_API_KEY`, `PERPLEXITY_API_KEY`

---

### Speech — Text-to-Speech & Speech-to-Text

These tools implement `IAiSpeechTool` — used when `SessionCaps` includes `cap_Speech`.  
Assign to `TAiChatConnection.SpeechTool`.

| Class | Service | Capabilities | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|---|
| `TAiOpenAISpeechTool` | **OpenAI** — Whisper STT + TTS voices (alloy, echo, fable, onyx, nova, shimmer). Industry standard. | TTS + STT | $5 credit on signup | TTS: $15/1M chars (tts-1). STT: $0.006/min | [platform.openai.com](https://platform.openai.com/api-keys) |
| `TAiGeminiSpeechTool` | **Google Gemini** — TTS with 30+ natural voices (`Puck`, `Aoede`, `Charon`…) and STT via audio inlineData. | TTS + STT | Generous free tier | Pay per token via Google AI Studio | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `TAiClaudeSTTTool` | **Anthropic Claude** — STT by sending audio as a document in the Messages API. No native TTS. | STT only | Paid only | Per-token (input tokens) | [console.anthropic.com](https://console.anthropic.com/settings/keys) |
| `TAiElevenLabsTool` | **ElevenLabs** — Highest quality multilingual TTS with voice cloning. Scribe v1 for STT. | TTS + STT | 10K chars/month | TTS from $5/month (30K chars). STT $0.40/hour | [elevenlabs.io](https://elevenlabs.io/app/sign-up) |
| `TAiAssemblyAISTTTool` | **AssemblyAI** — STT with speaker diarization, sentiment analysis, auto-chapters and highlights. | STT only | $50 free credit | $0.37/hour (best), $0.20/hour (nano) | [assemblyai.com](https://www.assemblyai.com/dashboard/signup) |
| `TAiDeepgramSTTTool` | **Deepgram Nova-3** — Ultra-fast, highly accurate STT. Supports 30+ languages, smart formatting and diarization. | STT only | $200 free credit | $0.0043/min (Nova-3) | [console.deepgram.com](https://console.deepgram.com/signup) |
| `TAiCartesiaTTSTool` | **Cartesia** — Low-latency TTS (Sonic series). Realistic voices, multiple audio formats. | TTS only | 50K chars/month | From $19/month (500K chars) | [play.cartesia.ai](https://play.cartesia.ai/sign-up) |
| `TAiFishAudioTTSTool` | **Fish Audio** — TTS using community voice models. Requires a `ReferenceId` from the Fish Audio model library. | TTS only | Free reference voices | $0.015/1,000 chars | [fish.audio](https://fish.audio/auth/login) |

**Key properties**: `ApiKey`, `TTSModel`, `STTModel`, `VoiceName`/`VoiceId`, `Language`.

---

### Vision — Image Description

These tools implement `IAiVisionTool` — used when `SessionCaps` includes `cap_Vision`.  
Assign to `TAiChatConnection.VisionTool`.

| Class | Service | Default Model | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|---|
| `TAiOpenAIVisionTool` | **OpenAI GPT-4o Vision** — Describe, analyze, and answer questions about images. Detail levels: `auto`, `low`, `high`. | `gpt-4o-mini` | $5 credit on signup | Per token (input image tokens) | [platform.openai.com](https://platform.openai.com/api-keys) |
| `TAiGeminiVisionTool` | **Google Gemini Vision** — Fast and accurate image understanding. Supports JPEG, PNG, GIF, WebP. | `gemini-2.5-flash` | Generous free tier | Per token via Google AI Studio | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `TAiClaudeVisionTool` | **Anthropic Claude Vision** — Detailed image analysis with nuanced reasoning. Images sent as base64 (image first in content array). | `claude-haiku-4-5-20251001` | Paid only | Per input token | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

**Key properties**: `ApiKey`, `Model`, `MaxTokens`, `DescriptionPrompt`.

---

### Image Generation

These tools implement `IAiImageTool` — used when `SessionCaps` includes `cap_GenImage`.  
Assign to `TAiChatConnection.ImageTool`.

| Class | Service | Default Model | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|---|
| `TAiFalAiImageTool` | **fal.ai** — Queue-based async inference platform hosting FLUX, LoRA and other diffusion models. Fast and scalable. | `fal-ai/flux/schnell` | Trial credits on signup | FLUX Schnell ~$0.003/image | [fal.ai](https://fal.ai/dashboard/keys) |
| `TAiIdeogramImageTool` | **Ideogram v2/v3** — Excels at text-in-image generation. Supports realistic, design, anime and 3D styles. | `V_2` | 10 slow images/day | From $8/month (basic plan) | [ideogram.ai/manage-api](https://ideogram.ai/manage-api) |
| `TAiReplicateImageTool` | **Replicate** — Run any open-source model version. Supports custom `owner/model:version` strings. | `black-forest-labs/flux-schnell` | $5 free credit | Pay-per-run: FLUX Schnell ~$0.003 | [replicate.com](https://replicate.com/signin) |
| `TAiStabilityAIImageTool` | **Stability AI** — Stable Diffusion 3.5. Synchronous multipart API returning binary PNG/JPEG directly. | `sd3.5-large` | 25 free credits | ~$0.04/image (SD3.5 Large) | [platform.stability.ai](https://platform.stability.ai/account/keys) |

**Key properties**: `ApiKey`, `ModelPath`/`Model`/`ModelVersion`, `ImageSize`/`AspectRatio`, `OutputFormat`, `NegativePrompt`.

---

### Video Generation

These tools implement `IAiVideoTool` — used when `SessionCaps` includes `cap_GenVideo`.  
Assign to `TAiChatConnection.VideoTool`.

| Class | Service | Default Model | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|---|
| `TAiGeminiVideoTool` | **Google Veo 2/3** — Text-to-video and image-to-video using Veo models. Long-Running Operation (LRO) pattern with async polling. | `veo-2.0-generate-001` | Limited via AI Studio | Per second of video via Google Cloud | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `TAiOpenAIVideoTool` | **OpenAI Sora** — Text-to-video generation. Async submit + poll pattern. Downloads require Bearer auth in GET. | `sora` | Paid only | Per-second pricing | [platform.openai.com](https://platform.openai.com/api-keys) |
| `TAiKlingAIVideoTool` | **Kling AI** — High-quality Chinese video model. Uses **JWT HMAC-SHA256** authentication (AccessKey + SecretKey). Requires two separate env vars. | `kling-v2` | 66 free credits/day | Paid plans at klingai.com | [platform.klingai.com](https://platform.klingai.com/account/keys) |
| `TAiRunwayMLVideoTool` | **Runway ML Gen-3/4** — Text/image-to-video. Requires `X-Runway-Version: 2024-11-06` header (mandatory). | `gen4_turbo` | 125 free credits | From $12/month (625 credits) | [app.runwayml.com](https://app.runwayml.com/login) |
| `TAiDIDVideoTool` | **D-ID** — Talking avatar videos. Animates a face image using text and Microsoft Neural TTS voices. Basic Auth with empty password (`key:`). | — | 20 free credits | From $5.9/month | [studio.d-id.com](https://studio.d-id.com/login) |

**Special auth notes:**
- **KlingAI**: env vars `KLINGAI_API_KEY` + `KLINGAI_API_SECRET` — JWT is generated and signed automatically.
- **Runway ML**: header `X-Runway-Version: 2024-11-06` is added automatically.
- **D-ID**: Basic Auth format `key:` (empty password) is handled automatically.

**Key properties**: `ApiKey`, `Model`, `DurationSeconds`/`Duration`/`Seconds`, `AspectRatio`, `Ratio`, `NegativePrompt`.

---

### PDF Parsing

These tools implement `IAiPdfTool` — used when `SessionCaps` includes `cap_Pdf`.  
Assign to `TAiChatConnection.PdfTool`.

| Class | Service | Output | Free Tier | Pricing | Get API Key |
|---|---|---|---|---|---|
| `TAiLlamaParseToolPdf` | **LlamaParse** — Cloud PDF parser by LlamaIndex. 3-step async flow: upload → poll → fetch. Returns markdown, text or JSON. | markdown / text / json | 1,000 pages/day | $3/1,000 pages (premium mode) | [cloud.llamaindex.ai](https://cloud.llamaindex.ai/) |
| `TAiMistralOcrTool` | **Mistral OCR** — `mistral-ocr-latest` endpoint (`/v1/ocr`). Synchronous. PDF sent as base64 data URL. Returns concatenated page markdown. | markdown | Paid only | $1/1,000 pages | [console.mistral.ai](https://console.mistral.ai/api-keys/) |
| `TAiReductoPdfTool` | **Reducto** — Advanced PDF parsing with table extraction, figure handling and page numbers. Supports both sync and async modes. | markdown | Free tier available | Pay per page | [app.reducto.ai](https://app.reducto.ai/) |
| `TAiUnstructuredPdfTool` | **Unstructured** — General-purpose document parsing. Uses custom header `unstructured-api-key` (not `Authorization`). Supports multiple strategies. | elements / markdown | 1,000 pages/month | Pay per page | [app.unstructured.io](https://app.unstructured.io/login) |

**Key properties**: `ApiKey`, `ResultType`/`OutputFormat`, `Language`, `PremiumMode`/`ParseMode`.  
**Env var convention**: `LLAMA_CLOUD_API_KEY`, `MISTRAL_API_KEY`, `REDUCTO_API_KEY`, `UNSTRUCTURED_API_KEY`

---

## Usage Examples

### Web Search with gap-analysis bridge

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
    Tavily.ApiKey      := '@TAVILY_API_KEY';
    Tavily.MaxResults  := 5;
    Tavily.IncludeAnswer := True;

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_WebSearch]';
    Conn.WebSearchTool := Tavily;

    Writeln(Conn.AddMessageAndRun('What are the top AI models of 2025?', 'user', []));
  finally
    Conn.WebSearchTool := nil;
    Conn.Free;
    Tavily.Free;
  end;
end;
```

### Direct call (without chat)

```pascal
uses uMakerAi.Core, uMakerAi.Chat.Messages, uMakerAi.Chat.Tools,
     uMakerAi.ChatTools.ElevenLabs;

var
  Tool  : TAiElevenLabsTool;
  AskMsg: TAiChatMessage;
  ResMsg: TAiChatMessage;
begin
  Tool   := TAiElevenLabsTool.Create(nil);
  AskMsg := TAiChatMessage.Create(nil);
  ResMsg := TAiChatMessage.Create(nil);
  try
    Tool.ApiKey          := '@ELEVENLABS_API_KEY';
    Tool.VoiceId         := 'JBFqnCBsd6RMkjVDRZzb'; // George
    Tool.TTSModel        := 'eleven_multilingual_v2';

    Tool.ExecuteSpeechGeneration('Hello, I am an AI assistant.', ResMsg, AskMsg);

    if ResMsg.MediaFiles.Count > 0 then
      ResMsg.MediaFiles[0].Stream.SaveToFile('output.mp3');
  finally
    ResMsg.Free; AskMsg.Free; Tool.Free;
  end;
end;
```

### PDF parsing with gap-analysis bridge

```pascal
uses uMakerAi.Chat.AiConnection, uMakerAi.Chat.Initializations,
     uMakerAi.ChatTools.LlamaParse;

var
  Conn      : TAiChatConnection;
  LlamaParse: TAiLlamaParseToolPdf;
  Media     : TAiMediaFile;
begin
  LlamaParse := TAiLlamaParseToolPdf.Create(nil);
  Media      := TAiMediaFile.Create(nil);
  Conn       := TAiChatConnection.Create(nil);
  try
    LlamaParse.ApiKey     := '@LLAMA_CLOUD_API_KEY';
    LlamaParse.ResultType := 'markdown';

    Media.LoadFromFile('document.pdf');

    Conn.DriverName := 'Claude';
    Conn.Model      := 'claude-haiku-4-5-20251001';
    Conn.Params.Values['ApiKey']       := '@CLAUDE_API_KEY';
    Conn.Params.Values['Asynchronous'] := 'False';
    Conn.Params.Values['ModelCaps']    := '[]';
    Conn.Params.Values['SessionCaps']  := '[cap_Pdf]';
    Conn.PdfTool := LlamaParse;

    // MakerAI detects gap → parses PDF with LlamaParse → injects markdown → completions
    Writeln(Conn.AddMessageAndRun('Summarize this document', 'user', [Media]));
  finally
    Conn.PdfTool := nil;
    Conn.Free; Media.Free; LlamaParse.Free;
  end;
end;
```

---

## Demos

Open `Demos/ChatToolsDemos.groupproj` in Delphi IDE to access all 58 demo projects.

Each service has two demos:
- **`01-DirectCall`** — standalone usage without `TAiChatConnection`
- **`02-ChatTools`** — full bridge integration with `TAiChatConnection` + gap analysis

---

## Adding a New Tool

1. Create `Source/<category>/uMakerAi.ChatTools.<Service>.pas`
2. Inherit from the correct base class:

   | Interface | Base Class | Method to implement |
   |---|---|---|
   | `IAiWebSearchTool` | `TAiWebSearchToolBase` | `ExecuteSearch` |
   | `IAiSpeechTool` | `TAiSpeechToolBase` | `ExecuteTranscription`, `ExecuteSpeechGeneration` |
   | `IAiVisionTool` | `TAiVisionToolBase` | `ExecuteImageDescription` |
   | `IAiImageTool` | `TAiImageToolBase` | `ExecuteImageGeneration` |
   | `IAiVideoTool` | `TAiVideoToolBase` | `ExecuteVideoGeneration` |
   | `IAiPdfTool` | `TAiPdfToolBase` | `ExecutePdfAnalysis` |

3. Use `ReportState`, `ReportDataEnd`, `ReportError` for lifecycle callbacks.
4. Add the unit to `Source/Packages/uMakerAi.ChatTools.dpk`.
5. Create `Demos/<Service>/01-DirectCall/` and `02-ChatTools/` demo projects.

---

## Environment Variables Summary

| Variable | Used by |
|---|---|
| `TAVILY_API_KEY` | TAiTavilyWebSearchTool |
| `BRAVE_API_KEY` | TAiBraveSearchTool |
| `SERPAPI_API_KEY` | TAiSerpApiWebSearchTool |
| `EXA_API_KEY` | TAiExaWebSearchTool |
| `PERPLEXITY_API_KEY` | TAiPerplexitySonarTool |
| `OPENAI_API_KEY` | TAiOpenAISpeechTool, TAiOpenAIVisionTool, TAiOpenAIVideoTool |
| `GEMINI_API_KEY` | TAiGeminiSpeechTool, TAiGeminiVisionTool, TAiGeminiVideoTool |
| `CLAUDE_API_KEY` | TAiClaudeSTTTool, TAiClaudeVisionTool |
| `ELEVENLABS_API_KEY` | TAiElevenLabsTool |
| `ASSEMBLYAI_API_KEY` | TAiAssemblyAISTTTool |
| `DEEPGRAM_API_KEY` | TAiDeepgramSTTTool |
| `CARTESIA_API_KEY` | TAiCartesiaTTSTool |
| `FISHAUDIO_API_KEY` | TAiFishAudioTTSTool |
| `FAL_API_KEY` | TAiFalAiImageTool |
| `IDEOGRAM_API_KEY` | TAiIdeogramImageTool |
| `REPLICATE_API_KEY` | TAiReplicateImageTool |
| `STABILITY_API_KEY` | TAiStabilityAIImageTool |
| `KLINGAI_API_KEY` + `KLINGAI_API_SECRET` | TAiKlingAIVideoTool |
| `RUNWAYML_API_KEY` | TAiRunwayMLVideoTool |
| `DID_API_KEY` | TAiDIDVideoTool |
| `LLAMA_CLOUD_API_KEY` | TAiLlamaParseToolPdf |
| `MISTRAL_API_KEY` | TAiMistralOcrTool |
| `REDUCTO_API_KEY` | TAiReductoPdfTool |
| `UNSTRUCTURED_API_KEY` | TAiUnstructuredPdfTool |

All tools support the `@VAR_NAME` convention: set `ApiKey := '@TAVILY_API_KEY'` and the
value is resolved via `GetEnvironmentVariable` at runtime.

---

## License

MIT License — Copyright (c) 2026 Gustavo Enríquez - CimaMaker

---

## Links

- **MakerAI (core framework):** https://github.com/gustavoeenriquez/MakerAi
- **Official website:** https://makerai.cimamaker.com
