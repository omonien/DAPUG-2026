{ -----------------------------------------------------------------------------
  /// <summary>
  ///   DUnitX tests for DX.DateChanger.Service using a mock IFileTimeSetter.
  /// </summary>
  /// <remarks>
  ///   Tests the orchestration logic without touching the file system: a
  ///   mock IFileTimeSetter records calls and can be configured to throw.
  ///   Each test creates real temp files only when it needs the orchestrator
  ///   to walk a directory or detect file vs. directory.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Service.Tests;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  DUnitX.TestFramework,
  DX.DateChanger.FileTime,
  DX.DateChanger.Service;

type
  TMockCall = record
    Path: string;
    Time: TDateTime;
  end;

  TMockFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  private
    FCalls: TList<TMockCall>;
    FFailWithCode: Integer;
    FFailForPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
    /// Configure: when SetTimes is called for AFailForPath, raise
    /// EFileTimeError with AOSErrorCode. Pass empty path to fail every call.
    procedure FailWith(const AFailForPath: string; AOSErrorCode: Integer);
    property Calls: TList<TMockCall> read FCalls;
  end;

  [TestFixture]
  TServiceTests = class
  private
    FMock: TMockFileTimeSetter;
    FMockIntf: IFileTimeSetter;
    FService: TDateChangerService;
    FTempDir: string;
    function MakeTempFile(const AName: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure ProcessDrop_EmptyArray_AllZero;
    [Test] procedure ProcessDrop_OneMatchingFile_ProcessedOne;
    [Test] procedure ProcessDrop_OneNonMatchingFile_SkippedOne;
    [Test] procedure ProcessDrop_MixedBatch_CountersCorrect;
    [Test] procedure ProcessDrop_MatchingFile_TimeIsTenAm;
    [Test] procedure ProcessDrop_FolderTopLevelOnly_SubdirsIgnored;
    [Test] procedure ProcessDrop_AccessDenied_CountedAsSkipped;
    [Test] procedure ProcessDrop_OtherError_CountedAsError;
    [Test] procedure ProcessDrop_NonExistentPath_CountedAsError;
    [Test] procedure ProcessDrop_ErrorsTriggerLogPath;
  end;

implementation

uses
  System.DateUtils;

const
{$IFDEF MSWINDOWS}
  cAccessDeniedCode = 5; // ERROR_ACCESS_DENIED
{$ELSE}
  cAccessDeniedCode = 13; // EACCES
{$ENDIF}

{ TMockFileTimeSetter }

constructor TMockFileTimeSetter.Create;
begin
  inherited Create;
  FCalls := TList<TMockCall>.Create;
  FFailWithCode := 0;
end;

destructor TMockFileTimeSetter.Destroy;
begin
  FCalls.Free;
  inherited;
end;

procedure TMockFileTimeSetter.FailWith(const AFailForPath: string; AOSErrorCode: Integer);
begin
  FFailForPath := AFailForPath;
  FFailWithCode := AOSErrorCode;
end;

procedure TMockFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LCall: TMockCall;
begin
  LCall.Path := APath;
  LCall.Time := AWhen;
  FCalls.Add(LCall);
  if (FFailWithCode <> 0) and ((FFailForPath = '') or (FFailForPath = APath)) then
    raise EFileTimeError.Create('mock failure', FFailWithCode);
end;

{ TServiceTests }

function TServiceTests.MakeTempFile(const AName: string): string;
begin
  Result := TPath.Combine(FTempDir, AName);
  TFile.WriteAllText(Result, 'x');
end;

procedure TServiceTests.Setup;
begin
  FMock := TMockFileTimeSetter.Create;
  FMockIntf := FMock;
  FService := TDateChangerService.Create(FMockIntf);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'dxdc_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TServiceTests.TearDown;
begin
  FreeAndNil(FService);
  FMockIntf := nil;
  FMock := nil;
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TServiceTests.ProcessDrop_EmptyArray_AllZero;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_OneMatchingFile_ProcessedOne;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28 photo.jpg');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(1, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
  Assert.AreEqual<Integer>(1, FMock.Calls.Count);
  Assert.AreEqual(LPath, FMock.Calls[0].Path);
end;

procedure TServiceTests.ProcessDrop_OneNonMatchingFile_SkippedOne;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('notes.txt');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
  Assert.AreEqual<Integer>(0, FMock.Calls.Count);
end;

procedure TServiceTests.ProcessDrop_MixedBatch_CountersCorrect;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([
    MakeTempFile('2026-04-28a.txt'),
    MakeTempFile('2026-04-29b.txt'),
    MakeTempFile('readme.md'),
    MakeTempFile('2026-13-01.txt') // invalid date, counts as skipped
  ]);
  Assert.AreEqual(2, LResult.Processed);
  Assert.AreEqual(2, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_MatchingFile_TimeIsTenAm;
var
  LPath: string;
  LResult: TDropResult;
  LExpected: TDateTime;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(1, LResult.Processed);
  LExpected := EncodeDateTime(2026, 4, 28, 10, 0, 0, 0);
  Assert.AreEqual(LExpected, FMock.Calls[0].Time);
end;

procedure TServiceTests.ProcessDrop_FolderTopLevelOnly_SubdirsIgnored;
var
  LSub: string;
  LResult: TDropResult;
begin
  MakeTempFile('2026-04-28a.txt'); // top level: matches
  MakeTempFile('readme.md');       // top level: skipped
  LSub := TPath.Combine(FTempDir, 'sub');
  TDirectory.CreateDirectory(LSub);
  TFile.WriteAllText(TPath.Combine(LSub, '2026-04-28b.txt'), 'x'); // ignored

  LResult := FService.ProcessDrop([FTempDir]);
  Assert.AreEqual(1, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_AccessDenied_CountedAsSkipped;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', cAccessDeniedCode);
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_OtherError_CountedAsError;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', 999);
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(1, LResult.Errors);
  Assert.IsTrue(LResult.LogPath <> '', 'LogPath should be populated when errors > 0');
end;

procedure TServiceTests.ProcessDrop_NonExistentPath_CountedAsError;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([TPath.Combine(FTempDir, 'does-not-exist.txt')]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(1, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_ErrorsTriggerLogPath;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', 999);
  LResult := FService.ProcessDrop([LPath]);
  Assert.IsTrue(TFile.Exists(LResult.LogPath), 'Error log file should be created');
end;

initialization
  TDUnitX.RegisterTestFixture(TServiceTests);

end.