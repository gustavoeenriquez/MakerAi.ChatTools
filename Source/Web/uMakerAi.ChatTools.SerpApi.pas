unit uMakerAi.ChatTools.SerpApi;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiSerpApiWebSearchTool
// Implementación de IAiWebSearchTool usando SerpAPI.
// https://serpapi.com/search-api
//
// Diferenciador: accede a multiples motores de búsqueda (Google, Bing,
// DuckDuckGo, Yahoo, YouTube, etc.) via una sola API.
// Tier gratuito: 100 búsquedas/mes.
//
// Env var requerida: SERPAPI_API_KEY
// Obtener en: https://serpapi.com/dashboard

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, System.NetEncoding,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiSerpApiWebSearchTool = class(TAiWebSearchToolBase)
  private
    FApiKey    : String;
    FEngine    : String;
    FNumResults: Integer;
    FHl        : String;
    FGl        : String;
    FLocation  : String;

    function ResolveApiKey: String;
    function BuildUrl(const AQuery: String): String;
    function FormatResults(AResponse: TJSONObject): String;
  protected
    procedure ExecuteSearch(const AQuery: String;
                            ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de SerpAPI. Soporta '@ENV_VAR' (default '@SERPAPI_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Motor de búsqueda: 'google', 'bing', 'duckduckgo', 'yahoo' (default 'google')
    property Engine: String read FEngine write FEngine;
    // Número de resultados (default 5)
    property NumResults: Integer read FNumResults write FNumResults default 5;
    // Idioma de la interfaz: 'es', 'en' (default 'es')
    property Hl: String read FHl write FHl;
    // Pais para los resultados: 'mx', 'us', 'es' (default 'mx')
    property Gl: String read FGl write FGl;
    // Geolocalizacion opciónal: 'Mexico City, Mexico' (vacio = sin filtro)
    property Location: String read FLocation write FLocation;
  end;

const
  SERPAPI_SEARCH_URL = 'https://serpapi.com/search.json';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiSerpApiWebSearchTool]);
end;

constructor TAiSerpApiWebSearchTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey     := '@SERPAPI_API_KEY';
  FEngine     := 'google';
  FNumResults := 5;
  FHl         := 'es';
  FGl         := 'mx';
  FLocation   := '';
end;

function TAiSerpApiWebSearchTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye la URL GET. La api_key va como query param (no en header).
// ---------------------------------------------------------------------------
function TAiSerpApiWebSearchTool.BuildUrl(const AQuery: String): String;
begin
  Result := SERPAPI_SEARCH_URL +
            '?api_key=' + ResolveApiKey +
            '&engine='  + FEngine +
            '&q='       + TNetEncoding.URL.Encode(AQuery) +
            '&num='     + IntToStr(FNumResults) +
            '&hl='      + FHl +
            '&gl='      + FGl;
  if FLocation <> '' then
    Result := Result + '&location=' + TNetEncoding.URL.Encode(FLocation);
end;

// ---------------------------------------------------------------------------
// Formatea la respuesta de SerpAPI.
// Si hay 'answer_box', lo muestra como respuesta directa (como Tavily answer).
// 'organic_results' usa campo 'link' (no 'url') y 'snippet' (no 'description').
// ---------------------------------------------------------------------------
function TAiSerpApiWebSearchTool.FormatResults(AResponse: TJSONObject): String;
var
  SB        : TStringBuilder;
  JAnswerBox: TJSONObject;
  JResults  : TJSONArray;
  JItem     : TJSONValue;
  JObj      : TJSONObject;
  Answer    : String;
  I         : Integer;
begin
  SB := TStringBuilder.Create;
  try
    // Respuesta directa de Google (cuadro de respuesta rapida)
    if AResponse.TryGetValue<TJSONObject>('answer_box', JAnswerBox) then
    begin
      // El answer_box puede tener 'answer' o 'snippet' dependiendo del tipo
      if not JAnswerBox.TryGetValue<String>('answer', Answer) then
        JAnswerBox.TryGetValue<String>('snippet', Answer);

      if Answer <> '' then
      begin
        SB.AppendLine('## Respuesta');
        SB.AppendLine(Answer);
        SB.AppendLine;
      end;
    end;

    // Resultados organicos
    if AResponse.TryGetValue<TJSONArray>('organic_results', JResults) and
       (JResults.Count > 0) then
    begin
      SB.AppendLine('## Fuentes');
      for I := 0 to JResults.Count - 1 do
      begin
        JItem := JResults.Items[I];
        if not (JItem is TJSONObject) then Continue;
        JObj := TJSONObject(JItem);

        SB.AppendFormat('[%d] %s', [I + 1, JObj.GetValue<String>('title', '')]);
        SB.AppendLine;
        // SerpAPI usa 'link' en lugar de 'url'
        SB.AppendLine(JObj.GetValue<String>('link', ''));
        // SerpAPI usa 'snippet' en lugar de 'content' o 'description'
        SB.AppendLine(JObj.GetValue<String>('snippet', ''));
        SB.AppendLine;
      end;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

procedure TAiSerpApiWebSearchTool.ExecuteSearch(const AQuery: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LText    : String;
begin
  ReportState(acsConnecting, 'SerpAPI [' + FEngine + ']: buscando — ' + AQuery);

  LClient := THTTPClient.Create;
  try
    try
      // SerpAPI: GET sin headers de autenticación (api_key va en la URL)
      LResponse := LClient.Get(BuildUrl(AQuery));

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('SerpAPI error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('SerpAPI: respuesta JSON invalida');
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
    LClient.Free;
  end;
end;

end.
