{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.TextChunker.Tests
  ///   Unit tests for SS.TextChunker.
  /// </summary>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.TextChunker.Tests;

interface

uses
  DUnitX.TestFramework, SS.TextChunker;

type
  [TestFixture]
  TTextChunkerTests = class
  public
    [Test]
    procedure EmptyText_ReturnsNoChunks;

    [Test]
    procedure ShortText_ReturnsSingleChunk;

    [Test]
    procedure LongText_SplitsIntoMultipleChunks;

    [Test]
    procedure ChunkCarriesMetadata;

    [Test]
    procedure ChunkDocument_PreservesPageNumbers;

    [Test]
    procedure OverlapChunks_DoNotExceedChunkSizeMassively;
  end;

implementation

uses
  System.SysUtils;

procedure TTextChunkerTests.EmptyText_ReturnsNoChunks;
var
  LChunks: TChunkArray;
begin
  LChunks := ChunkText('', 'test.pdf', 1, 0, 512, 64);
  Assert.AreEqual(Integer(0), Integer(Length(LChunks)));
end;

procedure TTextChunkerTests.ShortText_ReturnsSingleChunk;
var
  LChunks: TChunkArray;
begin
  LChunks := ChunkText('Hello world', 'test.pdf', 1, 0, 512, 64);
  Assert.AreEqual(Integer(1), Integer(Length(LChunks)));
  Assert.AreEqual('Hello world', LChunks[0].Text);
end;

procedure TTextChunkerTests.LongText_SplitsIntoMultipleChunks;
var
  LText: string;
  LChunks: TChunkArray;
  I: Integer;
begin
  LText := '';
  for I := 1 to 200 do
    LText := LText + 'This is sentence number ' + IntToStr(I) + '. ';
  LChunks := ChunkText(LText, 'test.pdf', 1, 0, 200, 40);
  Assert.IsTrue(Length(LChunks) > 1, 'Should produce more than one chunk');
end;

procedure TTextChunkerTests.ChunkCarriesMetadata;
var
  LChunks: TChunkArray;
begin
  LChunks := ChunkText('Some text', 'myfile.pdf', 3, 100, 512, 64);
  Assert.AreEqual(Integer(1), Integer(Length(LChunks)));
  Assert.AreEqual('myfile.pdf', LChunks[0].SourceFile);
  Assert.AreEqual(Integer(3), LChunks[0].PageNumber);
end;

procedure TTextChunkerTests.ChunkDocument_PreservesPageNumbers;
var
  LPages: TArray<string>;
  LChunks: TChunkArray;
begin
  SetLength(LPages, 3);
  LPages[0] := 'Page one text';
  LPages[1] := 'Page two text';
  LPages[2] := 'Page three text';
  LChunks := ChunkDocument(LPages, 'doc.pdf', 512, 64);
  Assert.IsTrue(Length(LChunks) >= 3, 'Should have at least one chunk per page');
  Assert.AreEqual(1, LChunks[0].PageNumber);
  Assert.AreEqual(2, LChunks[1].PageNumber);
  Assert.AreEqual(3, LChunks[2].PageNumber);
end;

procedure TTextChunkerTests.OverlapChunks_DoNotExceedChunkSizeMassively;
var
  LText: string;
  LChunks: TChunkArray;
  I: Integer;
begin
  LText := '';
  for I := 1 to 100 do
    LText := LText + 'Word' + IntToStr(I) + ' ';
  LChunks := ChunkText(LText, 'test.pdf', 1, 0, 80, 20);
  if Length(LChunks) > 1 then
    Assert.IsTrue(Length(LChunks[0].Text) <= 120,
      'First chunk should not massively exceed chunk size');
end;

initialization
  TDUnitX.RegisterTestFixture(TTextChunkerTests);

end.
