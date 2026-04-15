unit uMakerAi.ChatTools.BraveSearch;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiBraveSearchTool
// Implementación de IAiWebSearchTool usando la API de Brave Search.
// https://api.search.brave.com/app/documentation/web-search/get-started
//
// Diferenciador: motor de búsqueda propio (sin Google), orientado a privacidad.
// Tier gratuito: 2000 solicitudes/mes.
//
// Env var requerida: BRAVE_API_KEY
// Obtener en: https://api.search.brave.com/app/keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, System.NetEncoding,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiBraveSearchTool = class(TAiWebSearchToolBase)
  private
    FApiKey    : String;
    FCount     : Integer;
    FSearchLang: String;
    FCountry   : String;
    FSafesearch: String;

    function ResolveApiKey: String;
    function BuildUrl(const AQuery: String): String;
    function FormatResults(AResponse: TJSONObject): String;
  protected
    procedure ExecuteSearch(const AQuery: String;
                            ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Brave Search. Soporta '@ENV_VAR' (default '@BRAVE_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Número de resultados a retornar (1..20, default 5)
    property Count: Integer read FCount write FCount default 5;
    // Idioma de búsqueda: 'es', 'en', etc. (vacio = sin filtro)
    property SearchLang: String read FSearchLang write FSearchLang;
    // Pais de búsqueda: 'MX', 'ES', 'US', etc. (vacio = sin filtro)
    property Country: String read FCountry write FCountry;
    // Filtro de contenido: 'off', 'moderate', 'strict' (default 'moderate')
    property Safesearch: String read FSafesearch write FSafesearch;
  end;

const
  BRAVE_SEARCH_URL = 'https://api.search.brave.com/res/v1/web/search';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiBraveSearchTool]);
end;

constructor TAiBraveSearchTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey     := '@BRAVE_API_KEY';
  FCount      := 5;
  FSearchLang := '';
  FCountry    := '';
  FSafesearch := 'moderate';
end;

function TAiBraveSearchTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye la URL GET con los parametros de búsqueda.
// La autenticación va en header, no en la URL.
// ---------------------------------------------------------------------------
function TAiBraveSearchTool.BuildUrl(const AQuery: String): String;
begin
  Result := BRAVE_SEARCH_URL +
            '?q='         + TNetEncoding.URL.Encode(AQuery) +
            '&count='     + IntToStr(FCount);
  if FSearchLang <> '' then
    Result := Result + '&search_lang=' + FSearchLang;
  if FCountry <> '' then
    Result := Result + '&country=' + FCountry;
  if FSafesearch <> '' then
    Result := Result + '&safesearch=' + FSafesearch;
end;

// ---------------------------------------------------------------------------
// Formatea la respuesta de Brave en texto estructurado para el LLM.
// Brave no tiene campo 'answer' — solo lista de resultados.
// ---------------------------------------------------------------------------
function TAiBraveSearchTool.FormatResults(AResponse: TJSONObject): String;
var
  SB      : TStringBuilder;
  JWeb    : TJSONObject;
  JResults: TJSONArray;
  JItem   : TJSONValue;
  JObj    : TJSONObject;
  I       : Integer;
begin
  SB := TStringBuilder.Create;
  try
    // Brave estructura los resultados en response.web.results
    if not AResponse.TryGetValue<TJSONObject>('web', JWeb) then
    begin
      Result := '';
      Exit;
    end;

    if JWeb.TryGetValue<TJSONArray>('results', JResults) and
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
        SB.AppendLine(JObj.GetValue<String>('url', ''));
        SB.AppendLine(JObj.GetValue<String>('description', ''));
        SB.AppendLine;
      end;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Ejecuta la búsqueda con GET + headers de autenticación.
// Diferencia clave vs Tavily: autenticación en header, no en el body JSON.
// ---------------------------------------------------------------------------
procedure TAiBraveSearchTool.ExecuteSearch(const AQuery: String;
  ResMsg, AskMsg: TAiChatMessage);
var
  LClient  : THTTPClient;
  LResponse: IHTTPResponse;
  LResult  : TJSONObject;
  LHeaders : TNetHeaders;
  LText    : String;
begin
  ReportState(acsConnecting, 'Brave Search: buscando — ' + AQuery);

  LClient := THTTPClient.Create;
  try
    LHeaders := [
      TNetHeader.Create('X-Subscription-Token', ResolveApiKey),
      TNetHeader.Create('Accept', 'application/json')
    ];

    try
      LResponse := LClient.Get(BuildUrl(AQuery), nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Brave Search error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Brave Search: respuesta JSON invalida');
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
