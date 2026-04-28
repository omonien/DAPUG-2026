unit IUS.Tests.Storage;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TStorageTests = class
  strict private
    FRoot: string;
    function TempPath(const AName: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure ShouldDelete_WhenAgeExceedsRetention;
    [Test] procedure ShouldNotDelete_WhenAgeWithinRetention;
    [Test] procedure WriteThenRead_RoundTrip;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.DateUtils,
  IUS.Storage;

procedure TStorageTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'ius_test_' + TGuid.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
end;

procedure TStorageTests.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TStorageTests.TempPath(const AName: string): string;
begin
  Result := TPath.Combine(FRoot, AName);
end;

procedure TStorageTests.ShouldDelete_WhenAgeExceedsRetention;
var
  LCreated: TDateTime;
begin
  LCreated := IncMinute(Now, -45); // 45 min ago
  Assert.IsTrue(ShouldDelete(LCreated, 30, Now));
end;

procedure TStorageTests.ShouldNotDelete_WhenAgeWithinRetention;
var
  LCreated: TDateTime;
begin
  LCreated := IncMinute(Now, -5);
  Assert.IsFalse(ShouldDelete(LCreated, 30, Now));
end;

procedure TStorageTests.WriteThenRead_RoundTrip;
var
  LPath: string;
  LIn, LOut: TBytes;
begin
  LPath := TempPath('roundtrip.bin');
  LIn := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
  WriteAllBytes(LPath, LIn);
  LOut := ReadAllBytes(LPath);
  Assert.AreEqual(Length(LIn), Length(LOut));
  Assert.AreEqual<Byte>(LIn[5], LOut[5]);
end;

initialization
  TDUnitX.RegisterTestFixture(TStorageTests);

end.
