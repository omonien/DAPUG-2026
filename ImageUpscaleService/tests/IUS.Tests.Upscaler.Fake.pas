unit IUS.Tests.Upscaler.Fake;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFakeUpscalerTests = class
  public
    [Test] procedure Returns_NonEmptyPngBytes;
    [Test] procedure Result_StartsWithPngSignature;
    [Test] procedure CallCount_IncrementsPerCall;
  end;

implementation

uses
  System.SysUtils,
  IUS.Upscaler.Intf,
  IUS.Upscaler.Fake;

procedure TFakeUpscalerTests.Returns_NonEmptyPngBytes;
var
  LFake: IUpscaler;
  LResult: TBytes;
begin
  LFake := TFakeUpscaler.Create;
  LResult := LFake.Upscale(TBytes.Create(1, 2, 3), 'image/png', TUpscaleResolution.Res2K);
  Assert.IsTrue(Length(LResult) > 0);
end;

procedure TFakeUpscalerTests.Result_StartsWithPngSignature;
var
  LFake: IUpscaler;
  LResult: TBytes;
begin
  LFake := TFakeUpscaler.Create;
  LResult := LFake.Upscale(TBytes.Create(1), 'image/png', TUpscaleResolution.Res2K);
  Assert.AreEqual<Byte>($89, LResult[0]);
  Assert.AreEqual<Byte>($50, LResult[1]); // P
  Assert.AreEqual<Byte>($4E, LResult[2]); // N
  Assert.AreEqual<Byte>($47, LResult[3]); // G
end;

procedure TFakeUpscalerTests.CallCount_IncrementsPerCall;
var
  LFake: TFakeUpscaler;
  LIntf: IUpscaler;
begin
  LFake := TFakeUpscaler.Create;
  LIntf := LFake;
  Assert.AreEqual(0, LFake.CallCount);
  LIntf.Upscale(TBytes.Create(1), 'image/png', TUpscaleResolution.Res1K);
  LIntf.Upscale(TBytes.Create(1), 'image/png', TUpscaleResolution.Res4K);
  Assert.AreEqual(2, LFake.CallCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TFakeUpscalerTests);

end.
