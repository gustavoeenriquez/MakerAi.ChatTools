unit uMakerAi.ChatTools.Tavily;

// MIT License
//
// Copyright (c) 2026 Gustavo Enr?quez - CimaMaker
//
// TAiTavilyWebSearchTool
// Implementación de IAiWebSearchTool usando la API de búsqueda web de Tavily.
// https://docs.tavily.com/documentation/api-reference/endpoint/search
//
// Tavily es una API de búsqueda web optimizada para aplicaciones LLM.
// Devuelve resultados ya pre-procesados, listos para usar como contexto en
// RAG y agentes, incluyendo una respuesta sintetizada opcional.
//
// Uso como bridge automático (via TAiChatConnection):
//   Conn.Params.Values['ModelCaps']   := '[]';
//   Conn.Params.Values['SessionCaps'] := '[cap_WebSearch]';
//   Conn.WebSearchTool := TAiTavilyWebSearchTool.Create(nil);
//
// Uso directo (sin chat):
//   Tool.ExecuteSearch('mi pregunta', ResMsg, AskMsg);
//   Writeln(ResMsg.Prompt);
//
// Autor: Gustavo Enr?quez
// GitHub: https://github.com/gustavoeenriquez/MakerAi.ChatTools

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  // Profundidad de búsqueda.
  // tsdBasic    = rápido y económico, ideal para la mayoría de consultas.
  // tsdAdvanced = más resultados y mayor precisión, mayor latencia y costo.
  TTavilySearchDepth = (tsdBasic, tsdAdvanced);

  { TAiTavilyWebSearchTool -------------------------------------------------------
    Implementa IAiWebSearchTool usando la API REST de Tavily.

    Requiere una API key de Tavily (https://app.tavily.com).
    Por convención MakerAI se recomienda usar la variable de entorno TAVILY_API_KEY:
      Tool.ApiKey := '@TAVILY_API_KEY';

    Propiedades principales:
      ApiKey        — Clave de API. Acepta '@ENV_VAR' o valor literal.
      SearchDepth   — tsdBasic (default) o tsdAdvanced.
      MaxResults    — Número de resultados a devolver (1..20, default 5).
      IncludeAnswer — Si True, Tavily genera una respuesta directa además de los resultados.
      IncludeDomains / ExcludeDomains — Filtros opcionales de dominios.

    Resultado:
      La respuesta formateada se escribe en ResMsg.Prompt con este esquema:
        ## Respuesta
        <respuesta directa de Tavily si IncludeAnswer=True>

        ## Fuentes
        [1] Título
        URL
        Fragmento de contenido
        ...
  }
  TAiTavilyWebSearchTool = class(TAiWebSearchToolBase)
  private
    FApiKey        : String;
    FSearchDepth   : TTavilySearchDepth;
    FMaxResults    : Integer;
    FIncludeAnswer : Boolean;
    FIncludeDomains: TStringList;
    FExcludeDomains: TStringList;

    function ResolveApiKey: String;
    function BuildRequestJSON(const AQuery: String): TJSONObject;
    function FormatResults(AResponse: TJSONObject): String;
  protected
    procedure ExecuteSearch(const AQuery: String;
                            ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Lista de dominios a incluir en la búsqueda (vacío = sin filtro)
    property IncludeDomains: TStringList read FIncludeDomains;
    // Lista de dominios a excluir de la búsqueda
    property ExcludeDomains: TStringList read FExcludeDomains;
  published
    // API key de Tavily. Soporta sintaxis '@ENV_VAR' (p.ej. '@TAVILY_API_KEY')
    property ApiKey: String
             read FApiKey write FApiKey;
    // Profundidad de búsqueda: tsdBasic (rápido) o tsdAdvanced (completo)
    property SearchDepth: TTavilySearchDepth
             read FSearchDepth write FSearchDepth default tsdBasic;
    // Número máximo de resultados a retornar (1..20)
    property MaxResults: Integer
             read FMaxResults write FMaxResults default 5;
    // Si True, Tavily genera una respuesta directa además de los resultados
    property IncludeAnswer: Boolean
             read FIncludeAnswer write FIncludeAnswer default True;
  end;

const
  TAVILY_SEARCH_URL = 'https://api.tavily.com/search';

procedure Register;

implementation

{ TAiTavilyWebSearchTool }

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiTavilyWebSearchTool]);
end;

constructor TAiTavilyWebSearchTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey         := '@TAVILY_API_KEY';
  FSearchDepth    := tsdBasic;
  FMaxResults     := 5;
  FIncludeAnswer  := True;
  FIncludeDomains := TStringList.Create;
  FExcludeDomains := TStringList.Create;
end;

destructor TAiTavilyWebSearchTool.Destroy;
begin
  FIncludeDomains.Free;
  FExcludeDomains.Free;
  inherited;
end;

// ---------------------------------------------------------------------------
// Resuelve la API key: si empieza con '@', lee la variable de entorno.
// ---------------------------------------------------------------------------
function TAiTavilyWebSearchTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el payload JSON para el endpoint /search de Tavily.
// ---------------------------------------------------------------------------
function TAiTavilyWebSearchTool.BuildRequestJSON(const AQuery: String): TJSONObject;
const
  DEPTH_STR: array[TTavilySearchDepth] of String = ('basic', 'advanced');
var
  JArr: TJSONArray;
  I   : Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('api_key',      ResolveApiKey);
  Result.AddPair('query',        AQuery);
  Result.AddPair('search_depth', DEPTH_STR[FSearchDepth]);
  Result.AddPair('max_results',  TJSONNumber.Create(FMaxResults));
  Result.AddPair('include_answer', TJSONBool.Create(FIncludeAnswer));

  if FIncludeDomains.Count > 0 then
  begin
    JArr := TJSONArray.Create;
    for I := 0 to FIncludeDomains.Count - 1 do
      JArr.Add(FIncludeDomains[I]);
    Result.AddPair('include_domains', JArr);
  end;

  if FExcludeDomains.Count > 0 then
  begin
    JArr := TJSONArray.Create;
    for I := 0 to FExcludeDomains.Count - 1 do
      JArr.Add(FExcludeDomains[I]);
    Result.AddPair('exclude_domains', JArr);
  end;
end;

// ---------------------------------------------------------------------------
// Formatea la respuesta de Tavily en texto estructurado para el LLM.
// ---------------------------------------------------------------------------
function TAiTavilyWebSearchTool.FormatResults(AResponse: TJSONObject): String;
var
  SB      : TStringBuilder;
  JResults: TJSONArray;
  JItem   : TJSONValue;
  JObj    : TJSONObject;
  Answer  : String;
  I       : Integer;
begin
  SB := TStringBuilder.Create;
  try
    // Respuesta directa sintetizada por Tavily (si IncludeAnswer=True)
    if AResponse.TryGetValue<String>('answer', Answer) and (Answer <> '') then
    begin
      SB.AppendLine('## Respuesta');
      SB.AppendLine(Answer);
      SB.AppendLine;
    end;

    // Resultados de búsqueda individuales
    if AResponse.TryGetValue<TJSONArray>('results', JResults) and
       (JResults.Count > 0) then
    begin
      SB.AppendLine('## Fuentes');
      for I := 0 to JResults.Count - 1 do
      begin
        JItem := JResults.Items[I];
        if not (JItem is TJSONObject) then
          Continue;
        JObj := TJSONObject(JItem);

        SB.AppendFormat('[%d] %s', [I + 1, JObj.GetValue<String>('title', '')]);
        SB.AppendLine;
        SB.AppendLine(JObj.GetValue<String>('url', ''));
        SB.AppendLine(JObj.GetValue<String>('content', ''));
        SB.AppendLine;
      end;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Punto de entrada del bridge: llamado por TAiChat.InternalRunWebSearch.
// Hace POST a la API de Tavily, formatea el resultado y lo escribe en ResMsg.
// ---------------------------------------------------------------------------
procedure TAiTavilyWebSearchTool.ExecuteSearch(const AQuery: String;
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
  ReportState(acsConnecting, 'Tavily: buscando — ' + AQuery);

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AQuery);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    LHeaders := [TNetHeader.Create('Content-Type', 'application/json')];

    try
      LResponse := LClient.Post(TAVILY_SEARCH_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt(
          'Tavily API error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Tavily: respuesta JSON inválida');
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
