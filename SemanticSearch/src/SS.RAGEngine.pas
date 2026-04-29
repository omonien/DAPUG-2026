{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.RAGEngine
  ///   Orchestrates the full RAG pipeline: PDF extraction, chunking,
  ///   embedding, vector storage, retrieval, and LLM answer generation.
  /// </summary>
  /// <remarks>
  ///   The engine is the single entry point for the UI. It manages the
  ///   vector store lifecycle, deduplicates already-indexed files, and
  ///   wires together PdfExtractor, TextChunker, EmbeddingClient,
  ///   VectorStore, and ChatClient.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.RAGEngine;

interface

uses
  System.SysUtils, System.Classes,
  SS.Config, SS.TextChunker, SS.Embedding, SS.VectorStore, SS.ChatClient;

type
  TIndexProgress = reference to procedure(const AMessage: string; ACurrent, ATotal: Integer);

  TRAGEngine = class
  strict private
    FConfig: TConfig;
    FEmbeddingClient: TEmbeddingClient;
    FChatClient: TChatClient;
    FVectorStore: TVectorStore;
  public
    constructor Create(const AConfig: TConfig);
    destructor Destroy; override;
    procedure IndexPdf(const AFilePath: string; AProgress: TIndexProgress = nil);
    procedure IndexDirectory(const ADirPath: string; AProgress: TIndexProgress = nil);
    function Query(const AQuestion: string): string;
    function GetIndexedFiles: TArray<string>;
    function GetChunkCount: Integer;
    procedure SaveIndex;
  end;

function ResolvePath(const ABase, AFileName: string): string;

implementation

uses
  System.IOUtils, System.Math,
  SS.PdfExtractor;

function ResolvePath(const ABase, AFileName: string): string;
begin
  if TPath.IsPathRooted(ABase) then
    Result := ABase
  else
    Result := TPath.GetFullPath(ABase);
  if AFileName <> '' then
    Result := TPath.Combine(Result, AFileName);
end;

constructor TRAGEngine.Create(const AConfig: TConfig);
var
  LIndexPath: string;
begin
  inherited Create;
  FConfig := AConfig;
  FEmbeddingClient := TEmbeddingClient.Create(
    AConfig.EmbeddingApiKey, AConfig.EmbeddingModel, AConfig.EmbeddingBaseUrl);
  FChatClient := TChatClient.Create(
    AConfig.ChatApiKey, AConfig.ChatModel, AConfig.ChatBaseUrl, AConfig.ChatMaxTokens);

  LIndexPath := ResolvePath(AConfig.IndexDir, 'index.json');
  FVectorStore := TVectorStore.Create(LIndexPath);
  FVectorStore.LoadFromFile;
end;

destructor TRAGEngine.Destroy;
begin
  FVectorStore.Free;
  FChatClient.Free;
  FEmbeddingClient.Free;
  inherited;
end;

procedure TRAGEngine.IndexPdf(const AFilePath: string; AProgress: TIndexProgress);
var
  LFileName: string;
  LPages: TArray<string>;
  LChunks: TChunkArray;
  LChunk: TChunk;
  LEmbedding: TEmbeddingResult;
  LIdx, LTotal: Integer;
begin
  LFileName := TPath.GetFileName(AFilePath);
  if FVectorStore.HasFileIndexed(LFileName) then
  begin
    if Assigned(AProgress) then
      AProgress(Format('Skipping already indexed: %s', [LFileName]), 0, 0);
    Exit;
  end;

  if Assigned(AProgress) then
    AProgress(Format('Extracting text from: %s', [LFileName]), 0, 1);

  LPages := TPdfExtractor.ExtractPages(AFilePath);

  if Assigned(AProgress) then
    AProgress(Format('Chunking %d pages from: %s', [Length(LPages), LFileName]), 0, 1);

  LChunks := ChunkDocument(LPages, LFileName, FConfig.ChunkSize, FConfig.ChunkOverlap);
  LTotal := Length(LChunks);

  if Assigned(AProgress) then
    AProgress(Format('Embedding %d chunks from: %s', [LTotal, LFileName]), 0, LTotal);

  for LIdx := 0 to High(LChunks) do
  begin
    LChunk := LChunks[LIdx];
    if Trim(LChunk.Text) = '' then Continue;
    LEmbedding := FEmbeddingClient.GetEmbedding(LChunk.Text);
    FVectorStore.Add(LChunk, LEmbedding.Vector);
    if Assigned(AProgress) then
      AProgress(Format('Embedded chunk %d/%d', [LIdx + 1, LTotal]), LIdx + 1, LTotal);
  end;

  FVectorStore.SaveToFile;
  if Assigned(AProgress) then
    AProgress(Format('Indexed %s: %d chunks', [LFileName, LTotal]), LTotal, LTotal);
end;

procedure TRAGEngine.IndexDirectory(const ADirPath: string; AProgress: TIndexProgress);
var
  LFiles: TArray<string>;
  LFile: string;
  LIdx: Integer;
begin
  if not TDirectory.Exists(ADirPath) then
    raise Exception.CreateFmt('PDF directory not found: %s', [ADirPath]);

  LFiles := TDirectory.GetFiles(ADirPath, '*.pdf');
  if Length(LFiles) = 0 then
  begin
    if Assigned(AProgress) then
      AProgress('No PDF files found in directory.', 0, 0);
    Exit;
  end;

  for LIdx := 0 to High(LFiles) do
  begin
    LFile := LFiles[LIdx];
    if Assigned(AProgress) then
      AProgress(Format('Processing file %d/%d', [LIdx + 1, Length(LFiles)]), LIdx, Length(LFiles));
    IndexPdf(LFile, AProgress);
  end;
end;

function TRAGEngine.Query(const AQuestion: string): string;
var
  LQueryEmbedding: TEmbeddingResult;
  LResults: TArray<TSearchResult>;
  LContextChunks: TArray<string>;
  LResult: TSearchResult;
begin
  LQueryEmbedding := FEmbeddingClient.GetEmbedding(AQuestion);
  LResults := FVectorStore.Search(LQueryEmbedding.Vector, FConfig.TopK);
  SetLength(LContextChunks, Length(LResults));
  for var I := 0 to High(LResults) do
  begin
    LResult := LResults[I];
    LContextChunks[I] := Format('[Source: %s, Page %d, Score: %.2f] %s',
      [LResult.Chunk.SourceFile, LResult.Chunk.PageNumber, LResult.Score, LResult.Chunk.Text]);
  end;
  Result := FChatClient.ChatWithRAG(AQuestion, LContextChunks, FConfig.TopK);
end;

function TRAGEngine.GetIndexedFiles: TArray<string>;
begin
  Result := FVectorStore.GetIndexedFileNames;
end;

function TRAGEngine.GetChunkCount: Integer;
begin
  Result := FVectorStore.Count;
end;

procedure TRAGEngine.SaveIndex;
begin
  FVectorStore.SaveToFile;
end;

end.
