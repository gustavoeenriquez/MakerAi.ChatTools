unit uMakerAi.ChatTools.PerplexitySonar;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiPerplexitySonarTool
// Implementación de IAiWebSearchTool usando Perplexity Sonar.
// https://docs.perplexity.ai/api-reference/chat-completions
//
// IMPORTANTE: Perplexity Sonar NO es una API de búsqueda tradicional.
// Es una API de chat completions (compatible OpenAI) con grounding web
// automático. La "búsqueda" ocurre internamente: el modelo consulta
// la web y devuelve una respuesta ya sintetizada con citas.
//
// Diferencias vs otras WebSearch tools:
//   - El resultado ya es texto procesado, no lista de resultados crudos
//   - Las citas son URLs en array de strings, no objetos con título/contenido
//   - El modelo puede razonar sobre los resultados antes de responder
//
// Modelos disponibles:
//   'sonar'           = rápido, ideal para consultas simples
//   'sonar-pro'       = mas completo, mejor para preguntas complejas
//   'sonar-reasoning' = usa cadena de pensamiento antes de responder (lento)
//   'sonar-deep-research' = búsqueda profunda multi-paso (muy lento)
//
// Env var requerida: PERPLEXITY_API_KEY
// Obtener en: https://www.perplexity.ai/settings/api

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiPerplexitySonarTool = class(TAiWebSearchToolBase)
  private
    FApiKey                 : String;
    FModel                  : String;
    FMaxTokens              : Integer;
    FTemperature            : Single;
    FSearchRecencyFilter    : String;
    FReturnImages           : Boolean;
    FReturnRelatedQuestions : Boolean;

    function ResolveApiKey: String;
    function BuildRequestJSON(const AQuery: String): TJSONObject;
    function FormatResults(AResponse: TJSONObject): String;
  protected
    procedure ExecuteSearch(const AQuery: String;
                            ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Perplexity. Soporta '@ENV_VAR' (default '@PERPLEXITY_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Modelo Sonar: 'sonar', 'sonar-pro', 'sonar-reasoning' (default 'sonar')
    property Model: String read FModel write FModel;
    // Máximo de tokens en la respuesta (default 1024)
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 1024;
    // Temperatura 0.0-2.0; valores bajos = respuestas mas deterministas (default 0.2)
    // Nota: no soporta directiva 'default' por ser Single — asignado en constructor
    property Temperature: Single read FTemperature write FTemperature;
    // Filtro de recencia: 'month', 'week', 'day', 'hour' (vacio = sin filtro)
    property SearchRecencyFilter: String
             read FSearchRecencyFilter write FSearchRecencyFilter;
    // Si True, incluye imagenes en la respuesta (default False)
    property ReturnImages: Boolean
             read FReturnImages write FReturnImages default False;
    // Si True, incluye preguntas relacionadas al final (default False)
    property ReturnRelatedQuestions: Boolean
             read FReturnRelatedQuestions write FReturnRelatedQuestions default False;
  end;

const
  PERPLEXITY_CHAT_URL = 'https://api.perplexity.ai/chat/completions';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiPerplexitySonarTool]);
end;

constructor TAiPerplexitySonarTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey                 := '@PERPLEXITY_API_KEY';
  FModel                  := 'sonar';
  FMaxTokens              := 1024;
  FTemperature            := 0.2;
  FSearchRecencyFilter    := '';
  FReturnImages           := False;
  FReturnRelatedQuestions := False;
end;

function TAiPerplexitySonarTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body en formato chat/completions de OpenAI.
// La consulta va como mensaje de usuario, no como campo 'query'.
// ---------------------------------------------------------------------------
function TAiPerplexitySonarTool.BuildRequestJSON(const AQuery: String): TJSONObject;
var
  JMessages: TJSONArray;
  JMsg     : TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model',      FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
  Result.AddPair('temperature',TJSONNumber.Create(FTemperature));
  Result.AddPair('return_images',            TJSONBool.Create(FReturnImages));
  Result.AddPair('return_related_questions', TJSONBool.Create(FReturnRelatedQuestions));

  if FSearchRecencyFilter <> '' then
    Result.AddPair('search_recency_filter', FSearchRecencyFilter);

  // La consulta se envuelve como mensaje de usuario (formato chat completions)
  JMsg := TJSONObject.Create;
  JMsg.AddPair('role',    'user');
  JMsg.AddPair('content', AQuery);
  JMessages := TJSONArray.Create;
  JMessages.AddElement(JMsg);
  Result.AddPair('messages', JMessages);
end;

// ---------------------------------------------------------------------------
// Formatea la respuesta de Perplexity.
// A diferencia de las demas tools:
//   - El contenido principal esta en choices[0].message.content (texto sintetizado)
//   - Las citas estan en 'citations' como array de STRINGS (URLs), no objetos
// ---------------------------------------------------------------------------
function TAiPerplexitySonarTool.FormatResults(AResponse: TJSONObject): String;
var
  SB       : TStringBuilder;
  JChoices : TJSONArray;
  JChoice  : TJSONObject;
  JMessage : TJSONObject;
  JCitations: TJSONArray;
  Content  : String;
  I        : Integer;
begin
  SB := TStringBuilder.Create;
  try
    // Respuesta sintetizada del modelo
    if AResponse.TryGetValue<TJSONArray>('choices', JChoices) and
       (JChoices.Count > 0) then
    begin
      JChoice := TJSONObject(JChoices.Items[0]);
      if JChoice.TryGetValue<TJSONObject>('message', JMessage) then
      begin
        if JMessage.TryGetValue<String>('content', Content) and (Content <> '') then
        begin
          SB.AppendLine('## Respuesta');
          SB.AppendLine(Content);
          SB.AppendLine;
        end;
      end;
    end;

    // Citas: array de strings (URLs), no de objetos
    // Diferencia clave vs todas las demas tools de este paquete
    if AResponse.TryGetValue<TJSONArray>('citations', JCitations) and
       (JCitations.Count > 0) then
    begin
      SB.AppendLine('## Citas');
      for I := 0 to JCitations.Count - 1 do
        SB.AppendFormat('[%d] %s', [I + 1, JCitations.Items[I].Value]).AppendLine;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

procedure TAiPerplexitySonarTool.ExecuteSearch(const AQuery: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LRequest : TJSONObject;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
  LBody    : TStringStream;
  LText    : String;
begin
  ReportState(acsConnecting, 'Perplexity [' + FModel + ']: procesando — ' + AQuery);

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AQuery);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    // Autenticación identica a OpenAI: 'Authorization: Bearer {key}'
    LHeaders := [
      TNetHeader.Create('Authorization', 'Bearer ' + ResolveApiKey),
      TNetHeader.Create('Content-Type',  'application/json')
    ];

    try
      LResponse := LClient.Post(PERPLEXITY_CHAT_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Perplexity error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Perplexity: respuesta JSON invalida');
      try
        LText := FormatResults(LResult);
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
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

end.
