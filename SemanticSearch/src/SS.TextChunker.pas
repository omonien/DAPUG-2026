{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.TextChunker
  ///   Splits extracted text into overlapping chunks for RAG embedding.
  /// </summary>
  /// <remarks>
  ///   Uses recursive hierarchical splitting: paragraphs first, then
  ///   sentences, then words, then hard character split. Each chunk
  ///   carries metadata (source file, page number, character offset).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.TextChunker;

interface

type
  TChunk = record
    Text: string;
    SourceFile: string;
    PageNumber: Integer;
    CharOffset: Integer;
  end;

  TChunkArray = TArray<TChunk>;

  /// <summary>Splits text into overlapping chunks of approximately AChunkSize
  ///   characters, respecting paragraph and sentence boundaries.</summary>
  function ChunkText(const AText, ASourceFile: string;
    APageNumber, ACharOffset: Integer;
    AChunkSize, AOverlap: Integer): TChunkArray;

  /// <summary>Convenience: chunks all pages of a multi-page document at once.</summary>
  function ChunkDocument(const APages: TArray<string>;
    const ASourceFile: string;
    AChunkSize, AOverlap: Integer): TChunkArray;

implementation

uses
  System.SysUtils, System.StrUtils, System.Math;

function SplitBySeparator(const AText: string;
  const ASeparators: TArray<string>): TArray<string>;
var
  LBestPos, LPos, LIdx, LStart: Integer;
  LParts: TArray<string>;
begin
  SetLength(LParts, 0);
  LStart := 1;
  while LStart <= Length(AText) do
  begin
    LBestPos := 0;
    for LIdx := 0 to High(ASeparators) do
    begin
      LPos := AText.IndexOf(ASeparators[LIdx], LStart - 1);
      if (LPos >= LStart - 1) and ((LBestPos = 0) or (LPos + 1 < LBestPos)) then
        LBestPos := LPos + 1;
    end;
    if LBestPos = 0 then
    begin
      SetLength(LParts, Length(LParts) + 1);
      LParts[High(LParts)] := AText.Substring(LStart - 1);
      Break;
    end;
    SetLength(LParts, Length(LParts) + 1);
    LParts[High(LParts)] := AText.Substring(LStart - 1, LBestPos - LStart);
    LStart := LBestPos + 1;
  end;
  if Length(LParts) = 0 then
    LParts := [AText];
  Result := LParts;
end;

function SplitByParagraph(const AText: string): TArray<string>;
begin
  Result := AText.Split([sLineBreak + sLineBreak], TStringSplitOptions.None);
  if Length(Result) = 0 then
    Result := [AText];
end;

function SplitBySentence(const AText: string): TArray<string>;
var
  LParts: TArray<string>;
  LCurrent: string;
  LResult: TArray<string>;
  LPart: string;
begin
  LParts := AText.Split(['. ', '! ', '? '], TStringSplitOptions.None);
  if Length(LParts) <= 1 then
  begin
    SetLength(Result, 1);
    Result[0] := AText;
    Exit;
  end;

  SetLength(LResult, 0);
  LCurrent := '';
  for LPart in LParts do
  begin
    if LCurrent <> '' then
      LCurrent := LCurrent + '. ' + LPart
    else
      LCurrent := LPart;

    if Length(LCurrent) >= 50 then
    begin
      SetLength(LResult, Length(LResult) + 1);
      LResult[High(LResult)] := Trim(LCurrent);
      LCurrent := '';
    end;
  end;

  if LCurrent <> '' then
  begin
    if Length(LResult) > 0 then
      LResult[High(LResult)] := LResult[High(LResult)] + ' ' + Trim(LCurrent)
    else
    begin
      SetLength(LResult, Length(LResult) + 1);
      LResult[High(LResult)] := Trim(LCurrent);
    end;
  end;
  Result := LResult;
end;

function SplitByWord(const AText: string; AChunkSize: Integer): TArray<string>;
var
  LWords: TArray<string>;
  LCurrent: string;
  LResult: TArray<string>;
  LWord: string;
begin
  LWords := AText.Split([' '], TStringSplitOptions.None);
  SetLength(LResult, 0);
  LCurrent := '';
  for LWord in LWords do
  begin
    if (LCurrent <> '') and (Length(LCurrent) + 1 + Length(LWord) > AChunkSize) then
    begin
      SetLength(LResult, Length(LResult) + 1);
      LResult[High(LResult)] := LCurrent;
      LCurrent := LWord;
    end
    else
    begin
      if LCurrent <> '' then
        LCurrent := LCurrent + ' ' + LWord
      else
        LCurrent := LWord;
    end;
  end;
  if LCurrent <> '' then
  begin
    SetLength(LResult, Length(LResult) + 1);
    LResult[High(LResult)] := LCurrent;
  end;
  if Length(LResult) = 0 then
    Result := [AText]
  else
    Result := LResult;
end;

function ChunkText(const AText, ASourceFile: string;
  APageNumber, ACharOffset: Integer;
  AChunkSize, AOverlap: Integer): TChunkArray;
var
  LParagraphs, LSentences, LSubChunks: TArray<string>;
  LPara, LSentence: string;
  LCurrentText: string;
  LOffset: Integer;

  procedure FlushCurrent;
  var
    LChunk: TChunk;
    LLen: Integer;
  begin
    if LCurrentText = '' then Exit;
    LChunk.Text := Trim(LCurrentText);
    LChunk.SourceFile := ASourceFile;
    LChunk.PageNumber := APageNumber;
    LChunk.CharOffset := LOffset;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LChunk;
    LLen := Length(LCurrentText);
    if LLen > AOverlap then
      LCurrentText := RightStr(LCurrentText, AOverlap)
    else
      LCurrentText := '';
    LOffset := LOffset + AChunkSize - AOverlap;
  end;

begin
  SetLength(Result, 0);
  if Trim(AText) = '' then Exit;

  LOffset := ACharOffset;
  LCurrentText := '';

  LParagraphs := SplitByParagraph(AText);
  for LPara in LParagraphs do
  begin
    if Length(LPara) <= AChunkSize then
    begin
      if (LCurrentText <> '') and (Length(LCurrentText) + Length(LPara) + 2 > AChunkSize) then
        FlushCurrent;
      if LCurrentText <> '' then
        LCurrentText := LCurrentText + sLineBreak + sLineBreak + LPara
      else
        LCurrentText := LPara;
      Continue;
    end;

    LSentences := SplitBySentence(LPara);
    for LSentence in LSentences do
    begin
      if Length(LSentence) <= AChunkSize then
      begin
        if (LCurrentText <> '') and (Length(LCurrentText) + Length(LSentence) + 1 > AChunkSize) then
          FlushCurrent;
        if LCurrentText <> '' then
          LCurrentText := LCurrentText + ' ' + LSentence
        else
          LCurrentText := LSentence;
      end
      else
      begin
        LSubChunks := SplitByWord(LSentence, AChunkSize);
        for var LSub in LSubChunks do
        begin
          if (LCurrentText <> '') and (Length(LCurrentText) + Length(LSub) + 1 > AChunkSize) then
            FlushCurrent;
          if LCurrentText <> '' then
            LCurrentText := LCurrentText + ' ' + LSub
          else
            LCurrentText := LSub;
        end;
      end;
    end;
  end;
  FlushCurrent;
end;

function ChunkDocument(const APages: TArray<string>;
  const ASourceFile: string;
  AChunkSize, AOverlap: Integer): TChunkArray;
var
  LPageText: string;
  LPageIdx: Integer;
  LOffset: Integer;
  LChunks: TChunkArray;
  LChunk: TChunk;
begin
  SetLength(Result, 0);
  LOffset := 0;
  for LPageIdx := 0 to High(APages) do
  begin
    LPageText := APages[LPageIdx];
    LChunks := ChunkText(LPageText, ASourceFile, LPageIdx + 1, LOffset, AChunkSize, AOverlap);
    for LChunk in LChunks do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LChunk;
    end;
    Inc(LOffset, Length(LPageText));
  end;
end;

end.
