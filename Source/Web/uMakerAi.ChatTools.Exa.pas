unit uMakerAi.ChatTools.Exa;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiExaWebSearchTool
// Implementación de IAiWebSearchTool usando Exa AI Search.
// https://docs.exa.ai/reference/search
//
// Diferenciador: búsqueda semántica/neural. Puede incluir el contenido
// completo de cada página (campo 'text'), ideal para RAG y agentes que
// necesitan información detallada, no solo snippets.
//
// Tipos de búsqueda:
//   'neural'  = semántica, entiende el significado de la consulta
//   'keyword' = tradicional, coincidencia de palabras clave
//   'auto'    = el sistema elige segun la consulta (default)
//
// Env var requerida: EXA_API_KEY
// Obtener en: https://dashboard.exa.ai/api-keys

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  uMakerAi.Core,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TAiExaWebSearchTool = class(TAiWebSearchToolBase)
  private
    FApiKey            : String;
    FNumResults        : Integer;
    FUseAutoprompt     : Boolean;
    FSearchType        : String;
    FIncludeText       : Boolean;
    FTextMaxChars      : Integer;
    FStartPublishedDate: String;
    FEndPublishedDate  : String;

    function ResolveApiKey: String;
    function BuildRequestJSON(const AQuery: String): TJSONObject;
    function FormatResults(AResponse: TJSONObject): String;
  protected
    procedure ExecuteSearch(const AQuery: String;
                            ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // API key de Exa. Soporta '@ENV_VAR' (default '@EXA_API_KEY')
    property ApiKey: String read FApiKey write FApiKey;
    // Número de resultados (default 5)
    property NumResults: Integer read FNumResults write FNumResults default 5;
    // Si True, Exa mejora la consulta internamente antes de buscar (default True)
    property UseAutoprompt: Boolean read FUseAutoprompt write FUseAutoprompt default True;
    // Tipo de búsqueda: 'neural', 'keyword', 'auto' (default 'auto')
    property SearchType: String read FSearchType write FSearchType;
    // Si True, incluye el texto completo de cada página en los resultados
    property IncludeText: Boolean read FIncludeText write FIncludeText default True;
    // Caracteres máximos de texto por resultado (default 2000)
    property TextMaxChars: Integer read FTextMaxChars write FTextMaxChars default 2000;
    // Filtro por fecha de publicacion inicio (ISO 8601, vacio = sin filtro)
    property StartPublishedDate: String
             read FStartPublishedDate write FStartPublishedDate;
    // Filtro por fecha de publicacion fin (ISO 8601, vacio = sin filtro)
    property EndPublishedDate: String
             read FEndPublishedDate write FEndPublishedDate;
  end;

const
  EXA_SEARCH_URL = 'https://api.exa.ai/search';

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiExaWebSearchTool]);
end;

constructor TAiExaWebSearchTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FApiKey             := '@EXA_API_KEY';
  FNumResults         := 5;
  FUseAutoprompt      := True;
  FSearchType         := 'auto';
  FIncludeText        := True;
  FTextMaxChars       := 2000;
  FStartPublishedDate := '';
  FEndPublishedDate   := '';
end;

function TAiExaWebSearchTool.ResolveApiKey: String;
begin
  Result := FApiKey;
  if Result.StartsWith('@') then
    Result := GetEnvironmentVariable(Result.Substring(1));
end;

// ---------------------------------------------------------------------------
// Construye el body JSON para Exa.
// 'contents' es un sub-objeto que activa la extraccion de texto completo.
// ---------------------------------------------------------------------------
function TAiExaWebSearchTool.BuildRequestJSON(const AQuery: String): TJSONObject;
var
  JContents: TJSONObject;
  JText    : TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('query',         AQuery);
  Result.AddPair('numResults',    TJSONNumber.Create(FNumResults));
  Result.AddPair('useAutoprompt', TJSONBool.Create(FUseAutoprompt));
  Result.AddPair('type',          FSearchType);

  if FStartPublishedDate <> '' then
    Result.AddPair('startPublishedDate', FStartPublishedDate);
  if FEndPublishedDate <> '' then
    Result.AddPair('endPublishedDate', FEndPublishedDate);

  // Activar extraccion de texto completo de cada página
  if FIncludeText then
  begin
    JText     := TJSONObject.Create;
    JText.AddPair('maxCharacters', TJSONNumber.Create(FTextMaxChars));
    JContents := TJSONObject.Create;
    JContents.AddPair('text', JText);
    Result.AddPair('contents', JContents);
  end;
end;

// ---------------------------------------------------------------------------
// Formatea la respuesta de Exa.
// A diferencia de otros motores, el campo de contenido se llama 'text'
// (el contenido real de la página, no solo un snippet).
// Opciónalmente incluye 'publishedDate' para mostrar la fecha.
// ---------------------------------------------------------------------------
function TAiExaWebSearchTool.FormatResults(AResponse: TJSONObject): String;
var
  SB      : TStringBuilder;
  JResults: TJSONArray;
  JItem   : TJSONValue;
  JObj    : TJSONObject;
  LDate   : String;
  LText   : String;
  I       : Integer;
begin
  SB := TStringBuilder.Create;
  try
    if AResponse.TryGetValue<TJSONArray>('results', JResults) and
       (JResults.Count > 0) then
    begin
      SB.AppendLine('## Fuentes');
      for I := 0 to JResults.Count - 1 do
      begin
        JItem := JResults.Items[I];
        if not (JItem is TJSONObject) then Continue;
        JObj := TJSONObject(JItem);

        SB.AppendFormat('[%d] %s', [I + 1, JObj.GetValue<String>('title', '')]);

        // Mostrar fecha de publicacion si esta disponible
        if JObj.TryGetValue<String>('publishedDate', LDate) and (LDate <> '') then
          SB.AppendFormat(' (%s)', [Copy(LDate, 1, 10)]);  // solo YYYY-MM-DD

        SB.AppendLine;
        SB.AppendLine(JObj.GetValue<String>('url', ''));

        // 'text' es el contenido completo (si IncludeText=True)
        if JObj.TryGetValue<String>('text', LText) and (LText <> '') then
          SB.AppendLine(LText);

        SB.AppendLine;
      end;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

procedure TAiExaWebSearchTool.ExecuteSearch(const AQuery: String;
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
  ReportState(acsConnecting, 'Exa [' + FSearchType + ']: buscando — ' + AQuery);

  LClient  := THTTPClient.Create;
  LRequest := BuildRequestJSON(AQuery);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    // Autenticación en header 'x-api-key' (minusculas, sin 'Bearer')
    LHeaders := [
      TNetHeader.Create('x-api-key', ResolveApiKey),
      TNetHeader.Create('Content-Type', 'application/json')
    ];

    try
      LResponse := LClient.Post(EXA_SEARCH_URL, LBody, nil, LHeaders);

      if LResponse.StatusCode <> 200 then
        raise Exception.CreateFmt('Exa error %d: %s',
          [LResponse.StatusCode, LResponse.ContentAsString]);

      LResult := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LResult) then
        raise Exception.Create('Exa: respuesta JSON invalida');
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
