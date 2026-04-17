unit uMakerAi.ChatTools.NativePdf;

// MIT License - Copyright (c) 2026 Gustavo Enriquez - CimaMaker
//
// TAiNativePdfTool
// Implementacion 100% Delphi de IAiPdfTool usando la biblioteca PDF pura Delphi
// sin dependencias externas (reemplaza Ghostscript).
//
// ESTRATEGIA:
//   1. Extraer texto directamente de cada página vía TPDFTextExtractor
//   2. Si página tiene texto >= MinTextLength → usar directamente (sin IA)
//   3. Si página es imagen/escaneada (sin texto) → renderizar a PNG vía Skia
//      → pasar al TAiChat configurado con capacidad de visión
//   4. Procesar página por página, acumular resultados
//
// FLUJO POR PÁGINA:
//   TPDFDocument.LoadFromStream
//   ├─ for i := 0 to PageCount - 1
//   │  ├─ Extractor.ExtractPage(i) → TPDFPageText.PlainText
//   │  ├─ if Length(Text) >= MinTextLength
//   │  │  └─ usar texto directo → FullText.Append
//   │  └─ else
//   │     ├─ Renderer.RenderPageToImage → ISkImage (PNG bytes)
//   │     ├─ VisionChat.AddMessageAndRun (modo sincrónico en background thread)
//   │     └─ FullText.Append(resultado vision)
//   └─ poblate aMediaFile.Transcription
//
// REQUIERE:
//   - Biblioteca PDF pura Delphi: E:\Copilot\delphi-libraries\pdf\
//   - Skia4Delphi (FMX/System.Skia) para rendering
//   - TAiChat con cap_Image para el parámetro VisionChat (visión)
//
// API KEY: No aplica (100% local). Solo necesita VisionChat configurado con API key.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.StrUtils, System.Threading,
  System.JSON, System.Skia,
  uPDF.Document, uPDF.TextExtractor, uPDF.Render.Skia, uPDF.Render.Types,
  uPDF.Types, uPDF.Errors,
  uMakerAi.Core,
  uMakerAi.Chat,
  uMakerAi.Chat.Messages,
  uMakerAi.Chat.Tools;

type
  TOnNativePdfProgress = procedure(Sender: TObject; CurrentPage, TotalPages: Integer;
                                   const StatusMsg: string) of object;

  TAiNativePdfTool = class(TAiPdfToolBase)
  private
    FVisionChat    : TAiChat;
    FPrompt        : string;
    FDPI           : Integer;
    FMinTextLength : Integer;
    FOnProgress    : TOnNativePdfProgress;

    function RenderPageToMediaFile(Doc: TPDFDocument; PageIndex: Integer;
                                   const AName: string): TAiMediaFile;
    procedure DoProgress(Current, Total: Integer; const Msg: string);
    procedure InternalProcess(aMediaFile: TAiMediaFile; ResMsg, AskMsg: TAiChatMessage);

    procedure SetVisionChat(const Value: TAiChat);
  protected
    procedure ExecutePdfAnalysis(aMediaFile: TAiMediaFile; ResMsg, AskMsg: TAiChatMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function ExtractText(const APdfPath: string): string; overload;
    function ExtractText(AStream: TStream; const AFileName: string): string; overload;
  published
    property VisionChat: TAiChat read FVisionChat write SetVisionChat;
    property Prompt: string read FPrompt write FPrompt;
    property DPI: Integer read FDPI write FDPI default 150;
    property MinTextLength: Integer read FMinTextLength write FMinTextLength default 10;
    property OnProgress: TOnNativePdfProgress read FOnProgress write FOnProgress;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MakerAI ChatTools', [TAiNativePdfTool]);
end;

{ TAiNativePdfTool }

constructor TAiNativePdfTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPrompt := 'Extrae todo el texto e información visible de esta página del PDF.';
  FDPI := 150;
  FMinTextLength := 10;
end;

destructor TAiNativePdfTool.Destroy;
begin
  inherited Destroy;
end;

procedure TAiNativePdfTool.SetVisionChat(const Value: TAiChat);
begin
  FVisionChat := Value;
end;

procedure TAiNativePdfTool.DoProgress(Current, Total: Integer; const Msg: string);
begin
  if Assigned(FOnProgress) then
    TThread.Queue(nil, procedure begin
      FOnProgress(Self, Current, Total, Msg);
    end);
end;

function TAiNativePdfTool.RenderPageToMediaFile(Doc: TPDFDocument; PageIndex: Integer;
                                               const AName: string): TAiMediaFile;
var
  Page: TPDFPage;
  Opts: TPDFRenderOptions;
  Renderer: TPDFSkiaRenderer;
  SkImage: ISkImage;
  PngBytes: TBytes;
  MS: TMemoryStream;
  PixW, PixH: Integer;
begin
  Page := Doc.Pages[PageIndex];
  Opts := TPDFRenderOptions.ForPrint(FDPI);
  Renderer := TPDFSkiaRenderer.Create(Opts);
  try
    PixW := Round(Page.Width / 72.0 * FDPI);
    PixH := Round(Page.Height / 72.0 * FDPI);
    SkImage := Renderer.RenderPageToImage(Page, PixW, PixH);
    PngBytes := SkImage.EncodeToBytes(TSkEncodedImageFormat.PNG, 100);
  finally
    Renderer.Free;
  end;

  MS := TMemoryStream.Create;
  MS.Write(PngBytes[0], Length(PngBytes));
  MS.Position := 0;

  Result := TAiMediaFile.Create;
  Result.LoadFromStream(AName, MS);
  MS.Free;
end;

procedure TAiNativePdfTool.InternalProcess(aMediaFile: TAiMediaFile;
                                          ResMsg, AskMsg: TAiChatMessage);
var
  Doc: TPDFDocument;
  Extractor: TPDFTextExtractor;
  FullText: TStringBuilder;
  I: Integer;
  PageText: string;
  PText: TPDFPageText;
  PageMedia: TAiMediaFile;
  VText: string;
  OrigAsync: Boolean;
  LResult: string;
begin
  if not Assigned(aMediaFile) or not Assigned(ResMsg) then
    Exit;

  Doc := TPDFDocument.Create;
  Extractor := TPDFTextExtractor.Create(Doc);
  FullText := TStringBuilder.Create;

  try
    aMediaFile.Content.Position := 0;
    Doc.LoadFromStream(aMediaFile.Content);

    for I := 0 to Doc.PageCount - 1 do
    begin
      DoProgress(I + 1, Doc.PageCount, 'Procesando página ' + IntToStr(I + 1) + '/' + IntToStr(Doc.PageCount));

      // ESTRATEGIA 1: intentar extraer texto directo
      PText := Extractor.ExtractPage(I);
      PageText := Trim(PText.PlainText);

      if Length(PageText) >= FMinTextLength then
      begin
        // Página tiene texto — usar directamente sin IA
        FullText.AppendLine('--- PAGINA ' + IntToStr(I + 1) + ' ---');
        FullText.AppendLine(PageText);
      end
      else
      begin
        // ESTRATEGIA 2: renderizar y pasar por VisionChat
        if Assigned(FVisionChat) then
        begin
          try
            PageMedia := RenderPageToMediaFile(Doc, I, 'page_' + IntToStr(I + 1) + '.png');
            try
              FVisionChat.NewChat;
              OrigAsync := FVisionChat.Asynchronous;
              try
                FVisionChat.Asynchronous := False;
                VText := FVisionChat.AddMessageAndRun(FPrompt, 'user', [PageMedia]);
                FullText.AppendLine('--- PAGINA ' + IntToStr(I + 1) + ' (vision) ---');
                FullText.AppendLine(VText);
              finally
                FVisionChat.Asynchronous := OrigAsync;
              end;
            finally
              PageMedia.Free;
            end;
          except
            on E: Exception do
            begin
              FullText.AppendLine('--- PAGINA ' + IntToStr(I + 1) + ' (error vision) ---');
              FullText.AppendLine('Error: ' + E.Message);
              ReportError('Error procesando página ' + IntToStr(I + 1) + ' con vision: ' + E.Message, E);
            end;
          end;
        end
        else
        begin
          FullText.AppendLine('--- PAGINA ' + IntToStr(I + 1) + ' (sin vision) ---');
          FullText.AppendLine('(Sin VisionChat asignado para procesar página imagen)');
        end;
      end;
    end;

    LResult := FullText.ToString;

    // Enriquecer prompt del usuario con datos extraídos
    if Assigned(AskMsg) and (AskMsg.Prompt <> '') then
      AskMsg.Prompt := AskMsg.Prompt + #10 + 'PDF Data:' + #10 +
                       StringReplace(LResult, #13#10, '\n', [rfReplaceAll]);

    aMediaFile.Transcription := LResult;
    aMediaFile.Procesado := True;
    ResMsg.Content := LResult;
    ResMsg.Prompt := LResult;
    ResMsg.Role := 'assistant';

    ReportDataEnd(ResMsg, 'assistant', LResult);
    ReportState(acsFinished, 'Análisis PDF completado');

  except
    on E: Exception do
    begin
      ReportError('Error en InternalProcess: ' + E.Message, E);
      ReportState(acsError, 'Error: ' + E.Message);
    end;
  end;

  FullText.Free;
  Extractor.Free;
  Doc.Free;
end;

procedure TAiNativePdfTool.ExecutePdfAnalysis(aMediaFile: TAiMediaFile;
                                             ResMsg, AskMsg: TAiChatMessage);
begin
  if IsAsync then
    InternalProcess(aMediaFile, ResMsg, AskMsg)
  else
    TTask.Run(procedure begin
      InternalProcess(aMediaFile, ResMsg, AskMsg);
    end);
end;

function TAiNativePdfTool.ExtractText(const APdfPath: string): string;
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(APdfPath, fmOpenRead);
  try
    Result := ExtractText(FS, ExtractFileName(APdfPath));
  finally
    FS.Free;
  end;
end;

function TAiNativePdfTool.ExtractText(AStream: TStream; const AFileName: string): string;
var
  LMedia: TAiMediaFile;
  LResMsg, LAskMsg: TAiChatMessage;
begin
  Result := '';

  if not Assigned(AStream) then
    Exit;

  LMedia := TAiMediaFile.Create;
  LResMsg := TAiChatMessage.Create;
  LAskMsg := TAiChatMessage.Create;

  try
    LMedia.LoadFromStream(AFileName, AStream);
    LAskMsg.Prompt := '';

    InternalProcess(LMedia, LResMsg, LAskMsg);
    Result := LMedia.Transcription;
  finally
    LAskMsg.Free;
    LResMsg.Free;
    LMedia.Free;
  end;
end;

end.
