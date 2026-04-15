unit uMakerAi.ChatTools.Deepgram;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiDeepgramSTTTool
// Implementacion de IAiSpeechTool (solo ExecuteTranscription) usando Deepgram.
// https://developers.deepgram.com/reference/listen-file
//
// Deepgram es el STT mas rápido del grupo: una sola llamada HTTP sincrona.
// El audio se envia directamente en el body (no como multipart ni base64).
// La respuesta llega en milisegundos para audios cortos.
//
// Diferencias clave vs AssemblyAI:
//   - Sincrono (una sola llamada, sin polling)
//   - El body HTTP es el binario del audio directamente (no JSON)
//   - Content-Type debe coincidir con el formato del audio
//   - Autenticacion: 'Authorization: Token {key}' (no 'Bearer', no sin prefijo)
//
// NOTA: Solo implementa ExecuteTranscription. El metodo ExecuteSpeechGeneration
// queda como no-op (Deepgram no ofrece TTS en la API basica).
//
// Env var requerida: DEEPGRAM_API_KEY
// Obtener en: https://console.deepgram.com/signup

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiDeepgramSTTTool = class(TAiSpeechToolBase)
  private
    FApiKey        : String;
    FModel         : String;
    FLanguage      : String;
    FSmartFormat   : Boolean;
    FDiarize       : Boolean;
    FPunctuate     : Boolean;
    FUtterances    : Boolean;
    FDetectLanguage: Boolean;

    function ResolveApiKey: String;
    function BuildUrl: String;
    function GetMimeType(const AFileName: String): String;
  protected
    procedure ExecuteTranscription(aMediaFile: TAiMediaFile;
                                   ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Deepgram. Soporta '@ENV_VAR' (default '@DEEPGRAM_API_KEY')
    // Autenticacion: 'Authorization: Token {key}'
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo de transcripción: 'nova-3', 'nova-2', 'enhanced', 'base' (default 'nova-3')
    // nova-3 es el mas preciso; base es el mas económico
    property Model: String read FModel write FModel;
    // Idioma del audio: 'es', 'en-US', 'es-419', etc. (default 'es')
    // Si DetectLanguage=True, este valor se ignora
    property Language: String read FLanguage write FLanguage;
    // Si True, formatea números, fechas, monedas automaticamente (default True)
    property SmartFormat: Boolean read FSmartFormat write FSmartFormat default True;
    // Si True, identifica hablantes distintos en el audio (default False)
    property Diarize: Boolean read FDiarize write FDiarize default False;
    // Si True, agrega puntuacion automatica al texto (default True)
    property Punctuate: Boolean read FPunctuate write FPunctuate default True;
    // Si True, divide el texto en segmentos por pausas naturales (default False)
    property Utterances: Boolean read FUtterances write FUtterances default False;
    // Si True, detecta el idioma automaticamente (ignora Language) (default False)
    property DetectLanguage: Boolean
             read FDetectLanguage write FDetectLanguage default False;
  end;

const
  DEEPGRAM_LISTEN_URL = 'https://api.deepgram.com/v1/listen';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiDeepgramSTTTool]);
end;

constructor TAiDeepgramSTTTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@DEEPGRAM_API_KEY';
  FModel          := 'nova-3';
  FLanguage       := 'es';
  FSmartFormat    := True;
  FDiarize        := False;
  FPunctuate      := True;
  FUtterances     := False;
  FDetectLanguage := False;
end;

function TAiDeepgramSTTTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye la URL con los parametros de transcripción como query params.
// Deepgram configura todo en la URL, no en el body (que es el audio binario).
// ---------------------------------------------------------------------------
function TAiDeepgramSTTTool.BuildUrl: String;
begin
  Result := DEEPGRAM_LISTEN_URL +
            '?model='       + FModel +
            '&smart_format=' + BoolToStr(FSmartFormat, True).ToLower +
            '&punctuate='    + BoolToStr(FPunctuate, True).ToLower;

  if FDetectLanguage then
    Result := Result + '&detect_language=true'
  else if FLanguage <> '' then
    Result := Result + '&language=' + FLanguage;

  if FDiarize    then Result := Result + '&diarize=true';
  if FUtterances then Result := Result + '&utterances=true';
end;

// ---------------------------------------------------------------------------
// Determina el Content-Type del audio a partir de la extension del archivo.
// Deepgram requiere que el Content-Type coincida con el formato real del audio.
// ---------------------------------------------------------------------------
function TAiDeepgramSTTTool.GetMimeType(const AFileName: String): String;
var
  Ext: String;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if      Ext = '.mp3'  then Result := 'audio/mpeg'
  else if Ext = '.wav'  then Result := 'audio/wav'
  else if Ext = '.m4a'  then Result := 'audio/mp4'
  else if Ext = '.mp4'  then Result := 'audio/mp4'
  else if Ext = '.ogg'  then Result := 'audio/ogg'
  else if Ext = '.flac' then Result := 'audio/flac'
  else if Ext = '.webm' then Result := 'audio/webm'
  else if Ext = '.aac'  then Result := 'audio/aac'
  else                       Result := 'audio/mpeg';  // fallback seguro
end;

// ---------------------------------------------------------------------------
// Ejecuta la transcripción: POST síncrono con el audio binario en el body.
// Diferencia critica vs AssemblyAI: una sola llamada HTTP, sin polling.
// ---------------------------------------------------------------------------
procedure TAiDeepgramSTTTool.ExecuteTranscription(aMediaFile: TAiMediaFile;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient    : THTTPClient;
  LResponse  : IHTTPResponse;
  LResult    : TJSONObject;
  LAudioStream: TMemoryStream;
  LHeaders   : TNetHeaders;
  LText      : String;
  LChannels  : TJSONArray;
  LAlts      : TJSONArray;
  JChannel   : TJSONObject;
  JAlt       : TJSONObject;
begin
  if not Assigned(aMediaFile) or not Assigned(aMediaFile.Stream) then
  begin
    ReportError('Deepgram: archivo de audio no disponible', nil);
    Exit;
  end;

  ReportState(acsConnecting, 'Deepgram [' + FModel + ']: transcribiendo...');

  LClient      := THTTPClient.Create;
  LAudioStream := TMemoryStream.Create;
  try
    // Copiar el audio al stream de envio
    aMediaFile.Stream.Position := 0;
    LAudioStream.CopyFrom(aMediaFile.Stream, aMediaFile.Stream.Size);
    LAudioStream.Position := 0;

    // Autenticacion: 'Token {key}' (diferente a Bearer y a sin-prefijo de AssemblyAI)
    LHeaders := [
      TNetHeader.Create('Authorization', 'Token ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  GetMimeType(aMediaFile.FileName))
    ];

    try
      LResponse := LClient.Post(BuildUrl, LAudioStream, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Deepgram error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Deepgram: respuesta JSON invalida');
      try
        // Ruta: results.channels[0].alternatives[0].transcript
        if LResult.TryGetValue<TJSONArray>('results.channels', LChannels) and
           (LChannels.Count > 0) then
        begin
          JChannel := TJSONObject(LChannels.Items[0]);
          if JChannel.TryGetValue<TJSONArray>('alternatives', LAlts) and
             (LAlts.Count > 0) then
          begin
            JAlt  := TJSONObject(LAlts.Items[0]);
            LText := JAlt.GetValue<String>('transcript', '');
          end;
        end;
      finally
        LResult.Free;
      end;

      ResMsg.Prompt := LText;
      ReportDataEnd(ResMsg, 'assistant', LText);

    except
      on E: Exception do
      begin
        ReportError(E.Message, E);
        ResMsg.Prompt := '';
      end;
    end;
  finally
    LAudioStream.Free;
    LClient.Free;
  end;
end;

end.
