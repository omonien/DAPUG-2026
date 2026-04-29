unit IUS.Tests.Config;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TConfigTests = class
  strict private
    FIniPath: string;
    procedure WriteIni(const AContent: string);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Loads_AllFields_FromValidIni;
    [Test] procedure RaisesError_WhenApiKeyMissing;
    [Test] procedure RaisesError_WhenApiKeyDoesNotStartWithAIza;
    [Test] procedure RaisesError_WhenProviderInvalid;
    [Test] procedure DefaultsApplied_WhenOptionalKeysMissing;
    [Test] procedure DescribeModel_DefaultsTo_3_1_FlashLite_Preview;
    [Test] procedure DescribeModel_OverriddenInIniFile;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  IUS.Config;

procedure TConfigTests.Setup;
begin
  FIniPath := TPath.Combine(TPath.GetTempPath,
    'ius_cfg_' + TGuid.NewGuid.ToString + '.ini');
end;

procedure TConfigTests.TearDown;
begin
  if TFile.Exists(FIniPath) then TFile.Delete(FIniPath);
end;

procedure TConfigTests.WriteIni(const AContent: string);
begin
  TFile.WriteAllText(FIniPath, AContent);
end;

procedure TConfigTests.Loads_AllFields_FromValidIni;
var
  LCfg: TConfig;
begin
  WriteIni(
    '[Server]'#13#10'Port=8181'#13#10 +
    '[Gemini]'#13#10'ApiKey=AIzaXYZ'#13#10'Model=gemini-3-pro-image-preview'#13#10 +
    '[Upscaler]'#13#10'Provider=delphigemini'#13#10 +
    '[Storage]'#13#10'UploadDir=./var/u'#13#10'ResultDir=./var/r'#13#10 +
    'RetentionMinutes=42'#13#10);
  LCfg := LoadConfig(FIniPath);
  Assert.AreEqual(8181, LCfg.Port);
  Assert.AreEqual('AIzaXYZ', LCfg.ApiKey);
  Assert.AreEqual('gemini-3-pro-image-preview', LCfg.Model);
  Assert.AreEqual('delphigemini', LCfg.Provider);
  Assert.AreEqual('./var/u', LCfg.UploadDir);
  Assert.AreEqual('./var/r', LCfg.ResultDir);
  Assert.AreEqual(42, LCfg.RetentionMinutes);
end;

procedure TConfigTests.RaisesError_WhenApiKeyMissing;
begin
  WriteIni('[Gemini]'#13#10'ApiKey='#13#10);
  Assert.WillRaise(procedure begin LoadConfig(FIniPath); end, EConfigError);
end;

procedure TConfigTests.RaisesError_WhenApiKeyDoesNotStartWithAIza;
begin
  WriteIni('[Gemini]'#13#10'ApiKey=BogusKey'#13#10);
  Assert.WillRaise(procedure begin LoadConfig(FIniPath); end, EConfigError);
end;

procedure TConfigTests.RaisesError_WhenProviderInvalid;
begin
  WriteIni(
    '[Gemini]'#13#10'ApiKey=AIzaXYZ'#13#10 +
    '[Upscaler]'#13#10'Provider=openai'#13#10);
  Assert.WillRaise(procedure begin LoadConfig(FIniPath); end, EConfigError);
end;

procedure TConfigTests.DefaultsApplied_WhenOptionalKeysMissing;
var
  LCfg: TConfig;
begin
  WriteIni('[Gemini]'#13#10'ApiKey=AIzaXYZ'#13#10);
  LCfg := LoadConfig(FIniPath);
  Assert.AreEqual(8080, LCfg.Port);
  Assert.AreEqual('gemini-3-pro-image-preview', LCfg.Model);
  Assert.AreEqual('native', LCfg.Provider);
  Assert.AreEqual(30, LCfg.RetentionMinutes);
end;

procedure TConfigTests.DescribeModel_DefaultsTo_3_1_FlashLite_Preview;
var
  LCfg: TConfig;
begin
  WriteIni('[Gemini]'#13#10'ApiKey=AIzaXYZ'#13#10);
  LCfg := LoadConfig(FIniPath);
  Assert.AreEqual('gemini-3.1-flash-lite-preview', LCfg.DescribeModel);
end;

procedure TConfigTests.DescribeModel_OverriddenInIniFile;
var
  LCfg: TConfig;
begin
  WriteIni(
    '[Gemini]'#13#10'ApiKey=AIzaXYZ'#13#10 +
    '[Describer]'#13#10'Model=gemini-3-flash-preview'#13#10);
  LCfg := LoadConfig(FIniPath);
  Assert.AreEqual('gemini-3-flash-preview', LCfg.DescribeModel);
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigTests);

end.
