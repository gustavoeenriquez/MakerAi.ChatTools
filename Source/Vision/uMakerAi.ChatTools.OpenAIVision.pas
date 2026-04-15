unit uMakerAi.ChatTools.OpenAIVision;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiOpenAIVisionTool
// Implementacion de IAiVisionTool usando la API de OpenAI (GPT-4o/4.1).
// https://platform.openai.com/docs/guides/vision
//
// La imagen se envia como data URL base64 dentro del array 'content':
//   content[0] = {"type": "text", "text": "prompt"}
//   content[1] = {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,...", "detail": "auto"}}
//
// BRIDGE AUTOMATICO: cuando ModelCaps=[] y SessionCaps=[cap_Image],
//   RunNew detecta el gap y llama InternalRunImageDescription → VisionTool.
//   El desarrollador solo necesita: Conn.VisionTool := TAiOpenAIVisionTool.Create(nil)
//
// Env var requerida: OPENAI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiOpenAIVisionTool = class(TAiVisionToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FMaxTokens        : Integer;
    FDetail           : String;
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
    // API key de OpenAI. Soporta '@ENV_VAR' (default '@OPENAI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo con capacidad de vision: 'gpt-4o-mini', 'gpt-4o', 'gpt-4.1'
    // (default 'gpt-4o-mini' — balance calidad/costo)
    property Model: String read FModel write FModel;
    // Máximo de tokens en la descripción (default 1024)
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 1024;
    // Nivel de detalle de la imagen: 'auto', 'low', 'high' (default 'auto')
    // 'low' = mas rapido y economico; 'high' = mas preciso en imagenes grandes
    property Detail: String read FDetail write FDetail;
    // Prompt default cuando AskMsg.Prompt esta vacio
    property DescriptionPrompt: String
             read FDescriptionPrompt write FDescriptionPrompt;
  end;

const
  OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiOpenAIVisionTool]);
end;

constructor TAiOpenAIVisionTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@OPENAI_API_KEY';
  FModel             := 'gpt-4o-mini';
  FMaxTokens         := 1024;
  FDetail            := 'auto';
  FDescriptionPrompt := 'Describe esta imagen detalladamente.';
end;

function TAiOpenAIVisionTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiOpenAIVisionTool.GetImageMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      (Ext='.jpg') or (Ext='.jpeg') then Result := 'image/jpeg'
  else if Ext = '.png'  then Result := 'image/png'
  else if Ext = '.gif'  then Result := 'image/gif'
  else if Ext = '.webp' then Result := 'image/webp'
  else                       Result := 'image/jpeg';
end;

function TAiOpenAIVisionTool.BuildPrompt(const AAskPrompt: String): String;
begin
  Result := AAskPrompt;
  if Result.IsEmpty then Result := FDescriptionPrompt;
  if Result.IsEmpty then Result := 'Describe esta imagen detalladamente.';
end;

// ---------------------------------------------------------------------------
// Envia la imagen como data URL dentro del content array de messages.
// Diferencia vs Gemini: usa 'image_url' con campo 'url' y 'detail'.
// ---------------------------------------------------------------------------
procedure TAiOpenAIVisionTool.ExecuteImageDescription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LRequest  : TJSONObject;
  LBody     : TStringStream;
  LResult   : TJSONObject;
  JMessages : TJSONArray;
  JMsg      : TJSONObject;
  JContent  : TJSONArray;
  JTextPart : TJSONObject;
  JImgPart  : TJSONObject;
  JImgUrl   : TJSONObject;
  JChoices  : TJSONArray;
  JChoice   : TJSONObject;
  JMessage  : TJSONObject;
  LBytes    : TBytes;
  LBase64   : String;
  LDataUrl  : String;
  LText     : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('OpenAI Vision: imagen no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'OpenAI Vision [' + FModel + ']: analizando imagen...');

  // Codificar imagen en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64  := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  LDataUrl := 'data:' + GetImageMimeType(aMediaFile.FileName) + ';base64,' + LBase64;

  // Construir content array: [text, image_url]
  JTextPart := TJSONObject.Create;
  JTextPart.AddPair('type', 'text');
  JTextPart.AddPair('text', BuildPrompt(AskMsg.Prompt));

  JImgUrl := TJSONObject.Create;
  JImgUrl.AddPair('url',    LDataUrl);
  JImgUrl.AddPair('detail', FDetail);

  JImgPart := TJSONObject.Create;
  JImgPart.AddPair('type',      'image_url');
  JImgPart.AddPair('image_url', JImgUrl);

  JContent := TJSONArray.Create;
  JContent.AddElement(JTextPart);
  JContent.AddElement(JImgPart);

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
      LResponse := LClient.Post(OPENAI_CHAT_URL, LBody, nil, [
        TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
        TNetHeader.Create('Content-Type',  'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('OpenAI Vision error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('OpenAI Vision: respuesta JSON inválida');
      try
        if LResult.TryGetValue<TJSONArray>('choices', JChoices) and
           (JChoices.Count > 0) then
        begin
          JChoice := TJSONObject(JChoices.Items[0]);
          if JChoice.TryGetValue<TJSONObject>('message', JMessage) then
            JMessage.TryGetValue<String>('content', LText);
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
