{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.VectorStore.Tests
  ///   Unit tests for SS.VectorStore.
  /// </summary>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.VectorStore.Tests;

interface

uses
  DUnitX.TestFramework, SS.VectorStore, SS.TextChunker, SS.Embedding, System.IOUtils, System.SysUtils;

type
  [TestFixture]
  TVectorStoreTests = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AddAndCount;

    [Test]
    procedure SearchReturnsTopK;

    [Test]
    procedure SearchOrdersBySimilarity;

    [Test]
    procedure SaveAndLoad;

    [Test]
    procedure HasFileIndexed;

    [Test]
    procedure ClearRemovesAll;
  end;

implementation

procedure TVectorStoreTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'SS_VectorStoreTests_' + TGUID.NewGuid.ToString.Substring(0, 8));
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TVectorStoreTests.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TVectorStoreTests.AddAndCount;
var
  LStore: TVectorStore;
  LChunk: TChunk;
begin
  LStore := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.Text := 'hello';
    LChunk.SourceFile := 'a.pdf';
    LChunk.PageNumber := 1;
    LChunk.CharOffset := 0;
    LStore.Add(LChunk, [0.1, 0.2, 0.3]);
    Assert.AreEqual(Integer(1), LStore.Count);
    LStore.Add(LChunk, [0.4, 0.5, 0.6]);
    Assert.AreEqual(Integer(2), LStore.Count);
  finally
    LStore.Free;
  end;
end;

procedure TVectorStoreTests.SearchReturnsTopK;
var
  LStore: TVectorStore;
  LChunk: TChunk;
  LResults: TArray<TSearchResult>;
begin
  LStore := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.Text := 'first';
    LChunk.SourceFile := 'a.pdf';
    LChunk.PageNumber := 1;
    LChunk.CharOffset := 0;
    LStore.Add(LChunk, [1.0, 0.0, 0.0]);

    LChunk.Text := 'second';
    LStore.Add(LChunk, [0.0, 1.0, 0.0]);

    LChunk.Text := 'third';
    LStore.Add(LChunk, [0.0, 0.0, 1.0]);

    LResults := LStore.Search([1.0, 0.0, 0.0], 2);
    Assert.AreEqual(Integer(2), Integer(Length(LResults)));
    Assert.AreEqual('first', LResults[0].Chunk.Text);
  finally
    LStore.Free;
  end;
end;

procedure TVectorStoreTests.SearchOrdersBySimilarity;
var
  LStore: TVectorStore;
  LChunk: TChunk;
  LResults: TArray<TSearchResult>;
begin
  LStore := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.SourceFile := 'a.pdf';
    LChunk.PageNumber := 1;
    LChunk.CharOffset := 0;

    LChunk.Text := 'closest';
    LStore.Add(LChunk, [0.9, 0.1, 0.0]);

    LChunk.Text := 'medium';
    LStore.Add(LChunk, [0.5, 0.5, 0.0]);

    LChunk.Text := 'farthest';
    LStore.Add(LChunk, [0.1, 0.1, 0.9]);

    LResults := LStore.Search([1.0, 0.0, 0.0], 3);
    Assert.AreEqual(Integer(3), Integer(Length(LResults)));
    Assert.AreEqual('closest', LResults[0].Chunk.Text);
    Assert.IsTrue(LResults[0].Score > LResults[1].Score);
    Assert.IsTrue(LResults[1].Score > LResults[2].Score);
  finally
    LStore.Free;
  end;
end;

procedure TVectorStoreTests.SaveAndLoad;
var
  LStore1, LStore2: TVectorStore;
  LChunk: TChunk;
  LResults: TArray<TSearchResult>;
begin
  LStore1 := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.Text := 'persisted text';
    LChunk.SourceFile := 'saved.pdf';
    LChunk.PageNumber := 2;
    LChunk.CharOffset := 100;
    LStore1.Add(LChunk, [0.1, 0.2, 0.3]);
    LStore1.SaveToFile;
  finally
    LStore1.Free;
  end;

  LStore2 := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LStore2.LoadFromFile;
    Assert.AreEqual(Integer(1), LStore2.Count);
    LResults := LStore2.Search([0.1, 0.2, 0.3], 1);
    Assert.AreEqual(Integer(1), Integer(Length(LResults)));
    Assert.AreEqual('persisted text', LResults[0].Chunk.Text);
    Assert.AreEqual('saved.pdf', LResults[0].Chunk.SourceFile);
  finally
    LStore2.Free;
  end;
end;

procedure TVectorStoreTests.HasFileIndexed;
var
  LStore: TVectorStore;
  LChunk: TChunk;
begin
  LStore := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.Text := 'hello';
    LChunk.SourceFile := 'mydoc.pdf';
    LChunk.PageNumber := 1;
    LChunk.CharOffset := 0;
    LStore.Add(LChunk, [0.1]);
    Assert.IsTrue(LStore.HasFileIndexed('mydoc.pdf'));
    Assert.IsFalse(LStore.HasFileIndexed('other.pdf'));
  finally
    LStore.Free;
  end;
end;

procedure TVectorStoreTests.ClearRemovesAll;
var
  LStore: TVectorStore;
  LChunk: TChunk;
begin
  LStore := TVectorStore.Create(TPath.Combine(FTempDir, 'test.json'));
  try
    LChunk.Text := 'hello';
    LChunk.SourceFile := 'a.pdf';
    LChunk.PageNumber := 1;
    LChunk.CharOffset := 0;
    LStore.Add(LChunk, [0.1]);
    Assert.AreEqual(Integer(1), LStore.Count);
    LStore.Clear;
    Assert.AreEqual(Integer(0), LStore.Count);
  finally
    LStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVectorStoreTests);

end.
