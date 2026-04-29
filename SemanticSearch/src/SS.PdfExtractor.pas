{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.PdfExtractor
  ///   Extracts text from PDF files using DX.Pdfium4D.
  /// </summary>
  /// <remarks>
  ///   Returns text per page as a TArray<string> so the chunker can
  ///   preserve page boundaries as natural chunk delimiters.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.PdfExtractor;

interface

type
  TPdfExtractor = class
  public
    class function ExtractPages(const AFilePath: string): TArray<string>;
    class function ExtractAllText(const AFilePath: string): string;
  end;

implementation

uses
  System.SysUtils, System.Classes,
  DX.Pdf.Document;

class function TPdfExtractor.ExtractPages(const AFilePath: string): TArray<string>;
var
  LDoc: TPdfDocument;
  LPage: TPdfPage;
  LPageIdx: Integer;
begin
  LDoc := TPdfDocument.Create;
  try
    LDoc.LoadFromFile(AFilePath);
    SetLength(Result, LDoc.PageCount);
    for LPageIdx := 0 to LDoc.PageCount - 1 do
    begin
      LPage := LDoc.Pages[LPageIdx];
      Result[LPageIdx] := LPage.GetText(0, LPage.GetCharCount);
    end;
  finally
    LDoc.Free;
  end;
end;

class function TPdfExtractor.ExtractAllText(const AFilePath: string): string;
var
  LPages: TArray<string>;
  LBuilder: TStringBuilder;
  LPage: string;
begin
  LPages := ExtractPages(AFilePath);
  LBuilder := TStringBuilder.Create;
  try
    for LPage in LPages do
    begin
      if LBuilder.Length > 0 then
        LBuilder.AppendLine.AppendLine;
      LBuilder.Append(LPage);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

end.
