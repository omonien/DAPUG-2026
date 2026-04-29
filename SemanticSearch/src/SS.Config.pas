{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.Config
  ///   Loads + validates config.ini into a TConfig record.
  /// </summary>
  /// <remarks>
  ///   Fail-fast: any missing/invalid required field raises EConfigError
  ///   with a message that names the failing key.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.Config;

interface

uses
  System.SysUtils, System.IniFiles;

type
  EConfigError = class(Exception);

  TConfig = record
    EmbeddingApiKey: string;
    EmbeddingModel: string;
    EmbeddingBaseUrl: string;
    ChatApiKey: string;
    ChatModel: string;
    ChatBaseUrl: string;
    ChatMaxTokens: Integer;
    ChunkSize: Integer;
    ChunkOverlap: Integer;
    TopK: Integer;
    PdfDir: string;
    IndexDir: string;
  end;

function LoadConfig(const APath: string): TConfig;

implementation

function LoadConfig(const APath: string): TConfig;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(APath, TEncoding.UTF8);
  try
    Result.EmbeddingApiKey := Trim(LIni.ReadString('Embedding', 'ApiKey', ''));
    if Result.EmbeddingApiKey = '' then
      raise EConfigError.Create('[Embedding] ApiKey is empty. Provide an OpenAI-compatible API key.');
    Result.EmbeddingModel := LIni.ReadString('Embedding', 'Model', 'text-embedding-3-small');
    Result.EmbeddingBaseUrl := LIni.ReadString('Embedding', 'BaseUrl', 'https://api.openai.com/v1');

    Result.ChatApiKey := Trim(LIni.ReadString('Chat', 'ApiKey', ''));
    if Result.ChatApiKey = '' then
      raise EConfigError.Create('[Chat] ApiKey is empty. Provide an OpenAI-compatible API key.');
    Result.ChatModel := LIni.ReadString('Chat', 'Model', 'gemini-3.1-flash-lite-preview');
    Result.ChatBaseUrl := LIni.ReadString('Chat', 'BaseUrl', 'https://generativelanguage.googleapis.com/v1beta/openai');
    Result.ChatMaxTokens := LIni.ReadInteger('Chat', 'MaxTokens', 1024);

    Result.ChunkSize := LIni.ReadInteger('RAG', 'ChunkSize', 512);
    Result.ChunkOverlap := LIni.ReadInteger('RAG', 'ChunkOverlap', 64);
    if Result.ChunkOverlap >= Result.ChunkSize then
      raise EConfigError.CreateFmt('[RAG] ChunkOverlap (%d) must be less than ChunkSize (%d)',
        [Result.ChunkOverlap, Result.ChunkSize]);
    Result.TopK := LIni.ReadInteger('RAG', 'TopK', 5);

    Result.PdfDir := LIni.ReadString('Storage', 'PdfDir', './var/pdf');
    Result.IndexDir := LIni.ReadString('Storage', 'IndexDir', './var/index');
  finally
    LIni.Free;
  end;
end;

end.
