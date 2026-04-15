unit uMakerAi.ChatTools.ClaudeSpeech;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiClaudeSTTTool
// Implementacion de IAiSpeechTool (solo STT) usando la API de Anthropic Claude.
//
// Claude puede transcribir audio enviando el archivo como base64 en el campo
// 'document' del messages API. La respuesta de texto contiene la transcripción.
//
// NOTA: Solo ExecuteTranscription esta implementado.
// Claude no tiene TTS nativo — ExecuteSpeechGeneration es no-op.
//
// AUTENTICACION:
//   x-api-key: {key}
//   anthropic-version: 2023-06-01
//   content-type: application/json
//
// Env var requerida: CLAUDE_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiClaudeSTTTool = class(TAiSpeechToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FMaxTokens        : Integer;
    FTranscribePrompt : String;

    function ResolveApiKey: String;
    function GetAudioMimeType(const AFileName: String): String;
  protected
    // Claude no soporta TTS nativo — no-op heredado de la clase base
    // procedure ExecuteSpeechGeneration(...); override; — no se sobreescribe
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Anthropic. Soporta '@ENV_VAR' (default '@CLAUDE_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo Claude para transcripción (default 'claude-opus-4-6')
    property Model: String read FModel write FModel;
    // Maximo de tokens en la respuesta (default 2048)
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 2048;
    // Instruccion de transcripción enviada junto con el audio
    property TranscribePrompt: String read FTranscribePrompt write FTranscribePrompt;
  end;

const
  CLAUDE_MESSAGES_URL    = 'https://api.anthropic.com/v1/messages';
  CLAUDE_API_VERSION     = '2023-06-01';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiClaudeSTTTool]);
end;

constructor TAiClaudeSTTTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey          := '@CLAUDE_API_KEY';
  FModel           := 'claude-opus-4-6';
  FMaxTokens       := 2048;
  FTranscribePrompt:= 'Please transcribe this audio file accurately. ' +
                      'Return only the transcription text, no additional commentary.';
end;

function TAiClaudeSTTTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiClaudeSTTTool.GetAudioMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      Ext = '.mp3'  then Result := 'audio/mp3'
  else if Ext = '.wav'  then Result := 'audio/wav'
  else if Ext = '.m4a'  then Result := 'audio/mp4'
  else if Ext = '.ogg'  then Result := 'audio/ogg'
  else if Ext = '.flac' then Result := 'audio/flac'
  else if Ext = '.webm' then Result := 'audio/webm'
  else                       Result := 'audio/mp3';
end;

// ---------------------------------------------------------------------------
// STT: envia el audio como 'document' base64 en el messages API de Claude.
// Claude analiza el audio y devuelve la transcripción en su respuesta de texto.
//
// NOTA: El soporte de audio en Claude via 'document' type puede variar segun
// la version del modelo. Modelos recientes (claude-opus-4-6) tienen mayor
// capacidad multimodal incluyendo audio.
// ---------------------------------------------------------------------------
procedure TAiClaudeSTTTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient    : THTTPClient;
  LResponse  : IHTTPResponse;
  LRequest   : TJSONObject;
  LBody      : TStringStream;
  LResult    : TJSONObject;
  JMessages  : TJSONArray;
  JMsg       : TJSONObject;
  JContent   : TJSONArray;
  JTextBlock : TJSONObject;
  JDocBlock  : TJSONObject;
  JSource    : TJSONObject;
  LBytes     : TBytes;
  LBase64    : String;
  LMimeType  : String;
  LText      : String;
  JRespContent: TJSONArray;
  JRespBlock : TJSONObject;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Claude STT: archivo de audio no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'Claude STT [' + FModel + ']: transcribiendo...');

  // Codificar audio en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64   := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  LMimeType := GetAudioMimeType(aMediaFile.FileName);

  // Block de texto con la instruccion
  JTextBlock := TJSONObject.Create;
  JTextBlock.AddPair('type', 'text');
  JTextBlock.AddPair('text', FTranscribePrompt);

  // Block de audio como 'document' con source base64
  JSource := TJSONObject.Create;
  JSource.AddPair('type',       'base64');
  JSource.AddPair('media_type', LMimeType);
  JSource.AddPair('data',       LBase64);

  JDocBlock := TJSONObject.Create;
  JDocBlock.AddPair('type',   'document');
  JDocBlock.AddPair('source', JSource);

  JContent := TJSONArray.Create;
  JContent.AddElement(JTextBlock);
  JContent.AddElement(JDocBlock);

  JMsg := TJSONObject.Create;
  JMsg.AddPair('role',    'user');
  JMsg.AddPair('content', JContent);

  JMessages := TJSONArray.Create;
  JMessages.AddElement(JMsg);

  LRequest := TJSONObject.Create;
  LRequest.AddPair('model',      FModel);
  LRequest.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
  LRequest.AddPair('messages',   JMessages);

  LClient := THTTPClient.Create;
  LBody   := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResponse := LClient.Post(CLAUDE_MESSAGES_URL, LBody, nil, [
        TNetHeader.Create('x-api-key',         ResolveApiKey),
        TNetHeader.Create('anthropic-version', CLAUDE_API_VERSION),
        TNetHeader.Create('content-type',      'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Claude STT error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Claude STT: respuesta JSON invalida');
      try
        // Extraer texto: content[0].text
        if LResult.TryGetValue<TJSONArray>('content', JRespContent) and
           (JRespContent.Count > 0) then
        begin
          JRespBlock := TJSONObject(JRespContent.Items[0]);
          JRespBlock.TryGetValue<String>('text', LText);
        end;
      finally
        LResult.Free;
      end;

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);
    except
      on E: Exception do begin ReportError(E.Message, E); ResMsg.Prompt := ''; end;
    end;
  finally
    LBody.Free; LRequest.Free; LClient.Free;
  end;
end;

end.
