unit IUS.Tests.Smoke;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSmokeTests = class
  public
    /// <summary>Boots the server once for the whole fixture. THorse is global
    ///   class state, so spinning up per test would duplicate route handlers
    ///   in the router tree and corrupt the second + third runs.</summary>
    [SetupFixture] procedure SetupFixture;
    [TearDownFixture] procedure TearDownFixture;

    [Test] procedure Healthz_Returns200OkText;
    [Test] procedure GetIndex_Returns200WithUploadForm;
    [Test] procedure JobsRoute_AcceptsBraceWrappedGuid;
    [Test] procedure ResultRoute_DeleteAfterDownload_RemovesJobAndFiles;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.IOUtils,
  System.Net.HttpClient, System.Net.URLClient,
  Horse,
  IUS.JobQueue, IUS.Routes, IUS.Upscaler.Intf, IUS.Upscaler.Fake,
  IUS.Describer.Intf, IUS.Describer.Fake;

const
  cTestPort = 18080;

function ProjectRoot: string;
begin
  // The test exe lives at ImageUpscaleService/build/<plat>/<cfg>/<exe>.
  // Walk up three levels to the ImageUpscaleService folder (which holds templates/).
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..'));
end;

function TemplateDir: string;
begin
  Result := TPath.Combine(ProjectRoot, 'templates');
end;

function StaticDir: string;
begin
  Result := TPath.Combine(ProjectRoot, 'public');
end;

type
  TServerHarness = class
  strict private
    FQueue: TJobQueue;
    FFake: IUpscaler;
    FFakeDesc: IDescriber;
    FRoutes: TRoutesContext;
    FReady: TEvent;
    FThread: TThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    /// <summary>Direct queue access so tests can pre-populate jobs without
    ///   going through the multipart upload route.</summary>
    property Queue: TJobQueue read FQueue;
  end;

constructor TServerHarness.Create;
begin
  inherited;
  FQueue := TJobQueue.Create(20);
  FFake := TFakeUpscaler.Create;
  FFakeDesc := TFakeDescriber.Create;
  FRoutes := TRoutesContext.Create(FQueue, TemplateDir, StaticDir,
    TPath.Combine(ProjectRoot, 'var\uploads_smoke'),
    TPath.Combine(ProjectRoot, 'var\results_smoke'));
  FReady := TEvent.Create(nil, True, False, '');
end;

destructor TServerHarness.Destroy;
begin
  FReady.Free;
  FRoutes.Free;
  FQueue.Free;
  // FFake refcount drops with FQueue (it held the only reference via StartWorkers)
  inherited;
end;

procedure TServerHarness.Start;
var
  LReady: TEvent;
begin
  FRoutes.Register;
  FQueue.StartWorkers(1, FFake, FFakeDesc, TPath.Combine(ProjectRoot, 'var\results_smoke'));
  LReady := FReady;
  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(cTestPort,
        procedure begin LReady.SetEvent; end,
        nil);
    end);
  FThread.FreeOnTerminate := False;
  FThread.Start;
  // Wait up to 5 seconds for the server to come up
  if FReady.WaitFor(5000) <> wrSignaled then
    raise Exception.Create('Server did not start within 5 seconds');
end;

procedure TServerHarness.Stop;
begin
  THorse.StopListen;
  FQueue.StopWorkers;
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
end;

function HttpGet(const APath: string): IHTTPResponse;
var
  LClient: THTTPClient;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 3000;
    LClient.ResponseTimeout := 3000;
    Result := LClient.Get(Format('http://localhost:%d%s', [cTestPort, APath]));
  finally
    LClient.Free;
  end;
end;

var
  GHarness: TServerHarness;

procedure TSmokeTests.SetupFixture;
begin
  GHarness := TServerHarness.Create;
  GHarness.Start;
end;

procedure TSmokeTests.TearDownFixture;
begin
  GHarness.Stop;
  GHarness.Free;
  GHarness := nil;
end;

procedure TSmokeTests.Healthz_Returns200OkText;
var
  LResp: IHTTPResponse;
begin
  LResp := HttpGet('/healthz');
  Assert.AreEqual(200, LResp.StatusCode);
  Assert.AreEqual('ok', Trim(LResp.ContentAsString));
end;

procedure TSmokeTests.GetIndex_Returns200WithUploadForm;
var
  LResp: IHTTPResponse;
  LBody: string;
begin
  LResp := HttpGet('/');
  Assert.AreEqual(200, LResp.StatusCode);
  LBody := LResp.ContentAsString;
  Assert.Contains(LBody, 'hx-post="/upscale"');
  Assert.Contains(LBody, 'name="resolution"');
end;

procedure TSmokeTests.JobsRoute_AcceptsBraceWrappedGuid;
var
  LJob: TJob;
  LResp: IHTTPResponse;
  LSrc: string;
begin
  // Regression test for commit e0dde2f: the @jobId placeholder is rendered as
  // TGuid.ToString, which produces "{...}". Earlier the route handler wrapped
  // the URL param in another set of braces, so every poll fell to 404. This
  // test enqueues a job, then GETs /jobs/{...} with the canonical brace form
  // and expects 200, not 404.
  LSrc := TPath.Combine(TPath.GetTempPath,
    'smoke_' + TGuid.NewGuid.ToString + '.png');
  TFile.WriteAllBytes(LSrc, TBytes.Create($89, $50, $4E, $47));
  try
    Assert.IsTrue(GHarness.Queue.TryEnqueue('image/png', LSrc,
      TUpscaleResolution.Res2K, LJob));

    LResp := HttpGet('/jobs/' + LJob.Id.ToString);
    Assert.AreEqual(200, LResp.StatusCode,
      'GET /jobs/{guid} must return 200, not 404 ' +
      '(regression: doubled braces in TryParseJobId)');
  finally
    if TFile.Exists(LSrc) then TFile.Delete(LSrc);
  end;
end;

procedure TSmokeTests.ResultRoute_DeleteAfterDownload_RemovesJobAndFiles;
var
  LJob, LFetched: TJob;
  LResp: IHTTPResponse;
  LSrc, LResult: string;
begin
  LSrc := TPath.Combine(TPath.GetTempPath,
    'smoke_src_' + TGuid.NewGuid.ToString + '.png');
  LResult := TPath.Combine(TPath.GetTempPath,
    'smoke_result_' + TGuid.NewGuid.ToString + '.png');
  TFile.WriteAllBytes(LSrc, TBytes.Create($89, $50, $4E, $47));
  TFile.WriteAllBytes(LResult, TBytes.Create($89, $50, $4E, $47));
  try
    Assert.IsTrue(GHarness.Queue.TryEnqueue('image/png', LSrc,
      TUpscaleResolution.Res2K, LJob));
    GHarness.Queue.SetResult(LJob.Id, LResult);

    LResp := HttpGet('/result/' + LJob.Id.ToString + '?delete=1');

    Assert.AreEqual(200, LResp.StatusCode);
    Assert.IsFalse(GHarness.Queue.TryGet(LJob.Id, LFetched));
    Assert.IsFalse(TFile.Exists(LSrc));
    Assert.IsFalse(TFile.Exists(LResult));
  finally
    if TFile.Exists(LSrc) then TFile.Delete(LSrc);
    if TFile.Exists(LResult) then TFile.Delete(LResult);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSmokeTests);

end.
