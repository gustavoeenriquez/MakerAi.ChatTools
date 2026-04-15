unit uMakerAi.ChatTools.GeminiVision;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiGeminiVisionTool
// Implementacion de IAiVisionTool usando Google Gemini.
// https://ai.google.dev/gemini-api/docs/vision
//
// La imagen se envia como 'inlineData' en parts (mismo patron que GeminiSpeech STT).
// La diferencia es el mimeType: image/jpeg en lugar de audio/mp3.
//
// AUTENTICACION: query param ?key= — igual que todas las Gemini tools.
//
// Env var requerida: GEMINI_API_KEY

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiGeminiVisionTool = class(TAiVisionToolBase)
  private
    FApiKey           : String;
    FModel            : String;
    FMaxTokens        : Integer;
    FDescriptionPrompt: String;

    function ResolveApiKey: String;
    function GetApiUrl: String;
    function GetImageMimeType(const AFileName: String): String;
    function BuildPrompt(const AAskPrompt: String): String;
    function ExtractText(AResponse: TJSONObject): String;
  protected
    procedure ExecuteImageDescription(aMediaFile: TAiMediaFile;
                                      ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Gemini. Soporta '@ENV_VAR' (default '@GEMINI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo con vision: 'gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'
    // (default 'gemini-2.5-flash')
    property Model: String read FModel write FModel;
    // Máximo de tokens (default 1024)
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 1024;
    // Prompt default cuando AskMsg.Prompt esta vacio
    property DescriptionPrompt: String
             read FDescriptionPrompt write FDescriptionPrompt;
  end;

const
  GEMINI_VISION_BASE = 'https://generativelanguage.googleapis.com/v1beta/models/';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiGeminiVisionTool]);
end;

constructor TAiGeminiVisionTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey            := '@GEMINI_API_KEY';
  FModel             := 'gemini-2.5-flash';
  FMaxTokens         := 1024;
  FDescriptionPrompt := 'Describe esta imagen detalladamente.';
end;

function TAiGeminiVisionTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

function TAiGeminiVisionTool.GetApiUrl: String;
begin
  Result := GEMINI_VISION_BASE + FModel + ':generateContent?key=' + ResolveApiKey;
end;

function TAiGeminiVisionTool.GetImageMimeType(const AFileName: String): String;
var Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      (Ext='.jpg') or (Ext='.jpeg') then Result := 'image/jpeg'
  else if Ext = '.png'  then Result := 'image/png'
  else if Ext = '.gif'  then Result := 'image/gif'
  else if Ext = '.webp' then Result := 'image/webp'
  else if Ext = '.bmp'  then Result := 'image/bmp'
  else                       Result := 'image/jpeg';
end;

function TAiGeminiVisionTool.BuildPrompt(const AAskPrompt: String): String;
begin
  Result := AAskPrompt;
  if Result.IsEmpty then Result := FDescriptionPrompt;
  if Result.IsEmpty then Result := 'Describe esta imagen detalladamente.';
end;

// Extrae candidates[0].content.parts[0].text — mismo helper que GeminiSpeech
function TAiGeminiVisionTool.ExtractText(AResponse: TJSONObject): String;
var
  JCandidates: TJSONArray;
  JContent   : TJSONObject;
  JParts     : TJSONArray;
  JPart      : TJSONObject;
begin
  Result := '';
  if not AResponse.TryGetValue<TJSONArray>('candidates', JCandidates) or
     (JCandidates.Count = 0) then Exit;
  if not TJSONObject(JCandidates.Items[0]).TryGetValue<TJSONObject>('content', JContent) then Exit;
  if not JContent.TryGetValue<TJSONArray>('parts', JParts) or (JParts.Count = 0) then Exit;
  JPart := TJSONObject(JParts.Items[0]);
  JPart.TryGetValue<String>('text', Result);
end;

// ---------------------------------------------------------------------------
// Envia la imagen como inlineData en parts — idéntico patron que GeminiSpeech STT
// pero con mimeType de imagen en lugar de audio.
// ---------------------------------------------------------------------------
procedure TAiGeminiVisionTool.ExecuteImageDescription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient   : THTTPClient;
  LResponse : IHTTPResponse;
  LRequest  : TJSONObject;
  LBody     : TStringStream;
  LResult   : TJSONObject;
  JContents : TJSONArray;
  JContent  : TJSONObject;
  JParts    : TJSONArray;
  JTextPart : TJSONObject;
  JImgPart  : TJSONObject;
  JInline   : TJSONObject;
  JGenConf  : TJSONObject;
  LBytes    : TBytes;
  LBase64   : String;
  LText     : String;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Gemini Vision: imagen no disponible', nil); Exit;
  end;

  ReportState(acsConnecting, 'Gemini Vision [' + FModel + ']: analizando imagen...');

  // Codificar imagen en base64
  aMediaFile.Stream.Position := 0;
  SetLength(LBytes, aMediaFile.Stream.Size);
  aMediaFile.Stream.ReadBuffer(LBytes[0], aMediaFile.Stream.Size);
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);

  // Construir parts: [texto, inlineData imagen]
  JTextPart := TJSONObject.Create;
  JTextPart.AddPair('text', BuildPrompt(AskMsg.Prompt));

  JInline := TJSONObject.Create;
  JInline.AddPair('mimeType', GetImageMimeType(aMediaFile.FileName));
  JInline.AddPair('data',     LBase64);

  JImgPart := TJSONObject.Create;
  JImgPart.AddPair('inlineData', JInline);

  JParts := TJSONArray.Create;
  JParts.AddElement(JTextPart);
  JParts.AddElement(JImgPart);

  JContent := TJSONObject.Create;
  JContent.AddPair('parts', JParts);

  JContents := TJSONArray.Create;
  JContents.AddElement(JContent);

  JGenConf := TJSONObject.Create;
  JGenConf.AddPair('maxOutputTokens', TJSONNumber.Create(FMaxTokens));

  LRequest := TJSONObject.Create;
  LRequest.AddPair('contents',        JContents);
  LRequest.AddPair('generationConfig',JGenConf);

  LClient := THTTPClient.Create;
  LBody   := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResponse := LClient.Post(GetApiUrl, LBody, nil, [
        TNetHeader.Create('Content-Type', 'application/json')
      ]);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Gemini Vision error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Gemini Vision: respuesta JSON inválida');
      try
        LText := ExtractText(LResult);
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
