unit uMakerAi.ChatTools.ClaudeVision;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiClaudeVisionTool
// Implementacion de IAiVisionTool usando Anthropic Claude.
// https://docs.anthropic.com/en/docs/build-with-claude/vision
//
// La imagen se envia como bloque 'image' con source.type='base64'.
// ORDEN CRITICO en Claude: primero el bloque imagen, luego el texto.
//   content[0] = {"type":"image", "source":{"type":"base64","media_type":"image/jpeg","data":"..."}}
//   content[1] = {"type":"text", "text":"Describe esta imagen"}
//
// AUTENTICACION: 'x-api-key' + 'anthropic-version' — igual que ClaudeSpeech.
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
  TAiClaudeVisionTool = class(TAiVisionToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FMaxTokens        : Integer;
    FDescriptionPrompt: String;

    function ResolveApiKey: String;
    function GetImageMimeType(const AFileName: String): String;
    function BuildPrompt(const AAskPrompt: String): String;
  protected
    procedure ExecuteImageDescription(aMediaFile: TAiMediaFile;
                                      ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Anthropic. Soporta '@ENV_VAR' (default '@CLAUDE_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo con vision: 'claude-opus-4-6', 'claude-haiku-4-5-20251001'
    // (default 'claude-haiku-4-5-20251001' — balance calidad/costo/velocidad)
    property Model: String read FModel write FModel;
    // Máximo de tokens (default 1024)
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 1024;
    // Prompt default cuando AskMsg.Prompt esta vacio
    property DescriptionPrompt: String
             read FDescriptionPrompt write FDescriptionPrompt;
  end;

const
  CLAUDE_MESSAGES_URL = 'https://api.anthropic.com/v1/messages';
  CLAUDE_API_VERSION  = '2023-06-01';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiClaudeVisionTool]);
end;

constructor TAiClaudeVisionTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@CLAUDE_API_KEY';
  FModel             := 'claude-haiku-4-5-20251001';
  FMaxTokens         := 1024;
  FDescriptionPrompt := 'Describe esta imagen detalladamente.';
end;

function TAiClaudeVisionTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiClaudeVisionTool.GetImageMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      (Ext='.jpg') or (Ext='.jpeg') then Result := 'image/jpeg'
  else if Ext = '.png'  then Result := 'image/png'
  else if Ext = '.gif'  then Result := 'image/gif'
  else if Ext = '.webp' then Result := 'image/webp'
  else                       Result := 'image/jpeg';
end;

function TAiClaudeVisionTool.BuildPrompt(const AAskPrompt: String): String;
begin
  Result := AAskPrompt;
  if Result.IsEmpty then Result := FDescriptionPrompt;
  if Result.IsEmpty then Result := 'Describe esta imagen detalladamente.';
end;

// ---------------------------------------------------------------------------
// Envia imagen + texto en el content de Claude.
// DIFERENCIA CRITICA vs OpenAI: el bloque imagen va PRIMERO, el texto DESPUES.
// El 'source.type' es 'base64' (no 'image_url' como en OpenAI).
// ---------------------------------------------------------------------------
procedure TAiClaudeVisionTool.ExecuteImageDescription(aMediaFile: TAiMediaFile;
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
  JImgBlock  : TJSONObject;
  JSource    : TJSONObject;
  JTextBlock : TJSONObject;
  JRespContent: TJSONArray;
  JRespBlock : TJSONObject;
  LBytes     : TBytes;
  LBase64    : String;
  LText      : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Claude Vision: imagen no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'Claude Vision [' + FModel + ']: analizando imagen...');

  // Codificar imagen en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);

  // Bloque imagen (PRIMERO en Claude — orden importante)
  JSource := TJSONObject.Create;
  JSource.AddPair('type',       'base64');
  JSource.AddPair('media_type', GetImageMimeType(aMediaFile.FileName));
  JSource.AddPair('data',       LBase64);

  JImgBlock := TJSONObject.Create;
  JImgBlock.AddPair('type',   'image');
  JImgBlock.AddPair('source', JSource);

  // Bloque texto (DESPUES de la imagen)
  JTextBlock := TJSONObject.Create;
  JTextBlock.AddPair('type', 'text');
  JTextBlock.AddPair('text', BuildPrompt(AskMsg.Prompt));

  JContent := TJSONArray.Create;
  JContent.AddElement(JImgBlock);   // imagen primero
  JContent.AddElement(JTextBlock);  // texto despues

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
        raise Exception.CreateFmt('Claude Vision error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Claude Vision: respuesta JSON inválida');
      try
        // Extraer content[0].text
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
