unit IUS.Tests.Describer.Fake;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFakeDescriberTests = class
  public
    [Test] procedure Returns_NonEmptyTitleAndCaption;
    [Test] procedure CallCount_IncrementsPerCall;
    [Test] procedure RaiseOnNextCall_FlipsToConfiguredException;
  end;

implementation

uses
  System.SysUtils,
  IUS.Describer.Intf,
  IUS.Describer.Fake;

procedure TFakeDescriberTests.Returns_NonEmptyTitleAndCaption;
var
  LFake: IDescriber;
  LDesc: TDescription;
begin
  LFake := TFakeDescriber.Create;
  LDesc := LFake.Describe(TBytes.Create(1, 2, 3), 'image/png');
  Assert.IsTrue(Length(LDesc.Title) > 0);
  Assert.IsTrue(Length(LDesc.Caption) > 0);
end;

procedure TFakeDescriberTests.CallCount_IncrementsPerCall;
var
  LFake: TFakeDescriber;
  LIntf: IDescriber;
begin
  LFake := TFakeDescriber.Create;
  LIntf := LFake;
  Assert.AreEqual(0, LFake.CallCount);
  LIntf.Describe(TBytes.Create(1), 'image/png');
  LIntf.Describe(TBytes.Create(1), 'image/png');
  Assert.AreEqual(2, LFake.CallCount);
end;

procedure TFakeDescriberTests.RaiseOnNextCall_FlipsToConfiguredException;
var
  LFake: TFakeDescriber;
  LIntf: IDescriber;
begin
  LFake := TFakeDescriber.Create;
  LIntf := LFake;
  LFake.RaiseOnNextCall(EDescriberQuotaError);
  Assert.WillRaise(
    procedure begin LIntf.Describe(TBytes.Create(1), 'image/png'); end,
    EDescriberQuotaError);
end;

initialization
  TDUnitX.RegisterTestFixture(TFakeDescriberTests);

end.