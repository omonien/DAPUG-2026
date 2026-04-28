{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Smoke test for the platform IFileTimeSetter implementation. Creates
  ///   a temp file, calls SetTimes, reads timestamps back, asserts within
  ///   1-second tolerance.
  /// </summary>
  /// <remarks>
  ///   Cross-platform: runs on whichever OS the test suite is launched on.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.FileTime.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFileTimeTests = class
  public
    [Test] procedure SetTimes_Roundtrip_TimestampsMatchWithinOneSecond;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils,
  DX.DateChanger.FileTime;

procedure TFileTimeTests.SetTimes_Roundtrip_TimestampsMatchWithinOneSecond;
var
  LSetter: IFileTimeSetter;
  LPath: string;
  LWhen: TDateTime;
begin
  LSetter := CreateFileTimeSetter;
  LPath := TPath.Combine(TPath.GetTempPath, 'dxdc_smoke_' + TGUID.NewGuid.ToString + '.txt');
  TFile.WriteAllText(LPath, 'x');
  try
    LWhen := EncodeDateTime(2026, 4, 28, 10, 0, 0, 0);
    LSetter.SetTimes(LPath, LWhen);
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetCreationTime(LPath))) <= 1,
      'Creation time mismatch');
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetLastWriteTime(LPath))) <= 1,
      'Modification time mismatch');
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetLastAccessTime(LPath))) <= 1,
      'Access time mismatch');
  finally
    TFile.Delete(LPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFileTimeTests);

end.