{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.VectorStore
  ///   In-memory vector store with JSON file persistence and cosine
  ///   similarity search.
  /// </summary>
  /// <remarks>
  ///   Stores document chunks with their embedding vectors. Persists the
  ///   full index to a JSON file so it survives application restarts.
  ///   Search returns the top-K most similar chunks for a query vector.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.VectorStore;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  SS.TextChunker, SS.Embedding;

type
  TVectorEntry = record
    Chunk: TChunk;
    Vector: TEmbeddingVector;
  end;

  TSearchResult = record
    Chunk: TChunk;
    Score: Double;
  end;

  TVectorStore = class
  strict private
    FEntries: TList<TVectorEntry>;
    FIndexPath: string;
  public
    constructor Create(const AIndexPath: string);
    destructor Destroy; override;
    procedure Add(const AChunk: TChunk; const AVector: TEmbeddingVector);
    procedure Clear;
    function Count: Integer;
    function Search(const AQueryVector: TEmbeddingVector; ATopK: Integer): TArray<TSearchResult>;
    procedure SaveToFile;
    procedure LoadFromFile;
    function HasFileIndexed(const AFileName: string): Boolean;
    function GetIndexedFileNames: TArray<string>;
  end;

implementation

uses
  System.IOUtils, System.Math, System.Generics.Defaults;

constructor TVectorStore.Create(const AIndexPath: string);
begin
  inherited Create;
  FEntries := TList<TVectorEntry>.Create;
  FIndexPath := AIndexPath;
end;

destructor TVectorStore.Destroy;
begin
  FEntries.Free;
  inherited;
end;

procedure TVectorStore.Add(const AChunk: TChunk; const AVector: TEmbeddingVector);
var
  LEntry: TVectorEntry;
begin
  LEntry.Chunk := AChunk;
  LEntry.Vector := Copy(AVector);
  FEntries.Add(LEntry);
end;

procedure TVectorStore.Clear;
begin
  FEntries.Clear;
end;

function TVectorStore.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TVectorStore.Search(const AQueryVector: TEmbeddingVector;
  ATopK: Integer): TArray<TSearchResult>;
var
  LResults: TList<TSearchResult>;
  LEntry: TVectorEntry;
  LScore: Double;
  LResult: TSearchResult;
begin
  LResults := TList<TSearchResult>.Create;
  try
    for LEntry in FEntries do
    begin
      LScore := TEmbeddingClient.CosineSimilarity(AQueryVector, LEntry.Vector);
      LResult.Chunk := LEntry.Chunk;
      LResult.Score := LScore;
      LResults.Add(LResult);
    end;

    LResults.Sort(TComparer<TSearchResult>.Construct(
      function(const A, B: TSearchResult): Integer
      begin
        if A.Score > B.Score then
          Result := -1
        else if A.Score < B.Score then
          Result := 1
        else
          Result := 0;
      end));

    if LResults.Count > ATopK then
      LResults.DeleteRange(ATopK, LResults.Count - ATopK);

    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

procedure TVectorStore.SaveToFile;
var
  LRoot, LEntryObj, LChunkObj: TJSONObject;
  LEntriesArr: TJSONArray;
  LVectorArr: TJSONArray;
  LEntry: TVectorEntry;
  LDir: string;
begin
  LRoot := TJSONObject.Create;
  try
    LEntriesArr := TJSONArray.Create;
    for LEntry in FEntries do
    begin
      LEntryObj := TJSONObject.Create;
      LChunkObj := TJSONObject.Create;
      LChunkObj.AddPair('text', LEntry.Chunk.Text);
      LChunkObj.AddPair('sourceFile', LEntry.Chunk.SourceFile);
      LChunkObj.AddPair('pageNumber', TJSONNumber.Create(LEntry.Chunk.PageNumber));
      LChunkObj.AddPair('charOffset', TJSONNumber.Create(LEntry.Chunk.CharOffset));
      LEntryObj.AddPair('chunk', LChunkObj);

      LVectorArr := TJSONArray.Create;
      for var V in LEntry.Vector do
        LVectorArr.Add(V);
      LEntryObj.AddPair('vector', LVectorArr);
      LEntriesArr.AddElement(LEntryObj);
    end;
    LRoot.AddPair('entries', LEntriesArr);

    LDir := TPath.GetDirectoryName(FIndexPath);
    if (LDir <> '') and not TDirectory.Exists(LDir) then
      TDirectory.CreateDirectory(LDir);
    TFile.WriteAllText(FIndexPath, LRoot.Format(2), TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

procedure TVectorStore.LoadFromFile;
var
  LJson, LEntryObj, LChunkObj: TJSONObject;
  LEntriesArr: TJSONArray;
  LVectorArr: TJSONArray;
  I, J: Integer;
  LEntry: TVectorEntry;
begin
  if not TFile.Exists(FIndexPath) then Exit;
  FEntries.Clear;

  LJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(FIndexPath, TEncoding.UTF8)) as TJSONObject;
  if LJson = nil then Exit;
  try
    LEntriesArr := LJson.GetValue<TJSONArray>('entries');
    if LEntriesArr = nil then Exit;
    for I := 0 to LEntriesArr.Count - 1 do
    begin
      LEntryObj := LEntriesArr.Items[I] as TJSONObject;
      LChunkObj := LEntryObj.GetValue<TJSONObject>('chunk');
      LEntry.Chunk.Text := LChunkObj.GetValue<string>('text');
      LEntry.Chunk.SourceFile := LChunkObj.GetValue<string>('sourceFile');
      LEntry.Chunk.PageNumber := LChunkObj.GetValue<Integer>('pageNumber');
      LEntry.Chunk.CharOffset := LChunkObj.GetValue<Integer>('charOffset');

      LVectorArr := LEntryObj.GetValue<TJSONArray>('vector');
      SetLength(LEntry.Vector, LVectorArr.Count);
      for J := 0 to LVectorArr.Count - 1 do
        LEntry.Vector[J] := LVectorArr.Items[J].AsType<Double>;
      FEntries.Add(LEntry);
    end;
  finally
    LJson.Free;
  end;
end;

function TVectorStore.HasFileIndexed(const AFileName: string): Boolean;
var
  LEntry: TVectorEntry;
begin
  for LEntry in FEntries do
    if SameText(LEntry.Chunk.SourceFile, AFileName) then
      Exit(True);
  Result := False;
end;

function TVectorStore.GetIndexedFileNames: TArray<string>;
var
  LSet: TDictionary<string, Boolean>;
  LEntry: TVectorEntry;
begin
  LSet := TDictionary<string, Boolean>.Create;
  try
    for LEntry in FEntries do
      if not LSet.ContainsKey(LEntry.Chunk.SourceFile) then
        LSet.Add(LEntry.Chunk.SourceFile, True);
    Result := LSet.Keys.ToArray;
  finally
    LSet.Free;
  end;
end;

end.
