{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.Config.Tests
  ///   Unit tests for SS.Config.
  /// </summary>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.Config.Tests;

interface

uses
  DUnitX.TestFramework, SS.Config, System.SysUtils, System.IOUtils;

type
  [TestFixture]
  TConfigTests = class
  private
    FTempDir: string;
    procedure WriteTestConfig(const AContent: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ValidConfig_LoadsSuccessfully;

    [Test]
    procedure MissingEmbeddingApiKey_RaisesEConfigError;

    [Test]
    procedure MissingChatApiKey_RaisesEConfigError;

    [Test]
    procedure OverlapGreaterThanOrChunkSize_RaisesEConfigError;
  end;

implementation

procedure TConfigTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'SS_ConfigTests_' + TGUID.NewGuid.ToString.Substring(0, 8));
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TConfigTests.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TConfigTests.WriteTestConfig(const AContent: string);
begin
  TFile.WriteAllText(TPath.Combine(FTempDir, 'config.ini'), AContent, TEncoding.UTF8);
end;

procedure TConfigTests.ValidConfig_LoadsSuccessfully;
var
  LCfg: TConfig;
begin
  WriteTestConfig(
    '[Embedding]' + sLineBreak +
    'ApiKey=sk-test123' + sLineBreak +
    'Model=text-embedding-3-small' + sLineBreak +
    '[Chat]' + sLineBreak +
    'ApiKey=sk-chat456' + sLineBreak +
    'Model=gpt-4.1-mini' + sLineBreak);
  LCfg := LoadConfig(TPath.Combine(FTempDir, 'config.ini'));
  Assert.AreEqual('sk-test123', LCfg.EmbeddingApiKey);
  Assert.AreEqual('sk-chat456', LCfg.ChatApiKey);
end;

procedure TConfigTests.MissingEmbeddingApiKey_RaisesEConfigError;
var
  LRaised: Boolean;
begin
  WriteTestConfig(
    '[Embedding]' + sLineBreak +
    'ApiKey=' + sLineBreak +
    '[Chat]' + sLineBreak +
    'ApiKey=sk-test' + sLineBreak);
  LRaised := False;
  try
    LoadConfig(TPath.Combine(FTempDir, 'config.ini'));
  except
    on E: EConfigError do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised, 'Expected EConfigError for empty Embedding ApiKey');
end;

procedure TConfigTests.MissingChatApiKey_RaisesEConfigError;
var
  LRaised: Boolean;
begin
  WriteTestConfig(
    '[Embedding]' + sLineBreak +
    'ApiKey=sk-test' + sLineBreak +
    '[Chat]' + sLineBreak +
    'ApiKey=' + sLineBreak);
  LRaised := False;
  try
    LoadConfig(TPath.Combine(FTempDir, 'config.ini'));
  except
    on E: EConfigError do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised, 'Expected EConfigError for empty Chat ApiKey');
end;

procedure TConfigTests.OverlapGreaterThanOrChunkSize_RaisesEConfigError;
var
  LRaised: Boolean;
begin
  WriteTestConfig(
    '[Embedding]' + sLineBreak +
    'ApiKey=sk-test' + sLineBreak +
    '[Chat]' + sLineBreak +
    'ApiKey=sk-test' + sLineBreak +
    '[RAG]' + sLineBreak +
    'ChunkSize=50' + sLineBreak +
    'ChunkOverlap=50' + sLineBreak);
  LRaised := False;
  try
    LoadConfig(TPath.Combine(FTempDir, 'config.ini'));
  except
    on E: EConfigError do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised, 'Expected EConfigError when ChunkOverlap >= ChunkSize');
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigTests);

end.
