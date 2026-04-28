unit IUS.Tests.Smoke;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSmokeTests = class
  public
    [Test] procedure Healthz_Returns200OkText;
    [Test] procedure GetIndex_Returns200WithUploadForm;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.IOUtils,
  System.Net.HttpClient, System.Net.URLClient,
  Horse,
  IUS.JobQueue, IUS.Routes, IUS.Upscaler.Intf, IUS.Upscaler.Fake;

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
    FRoutes: TRoutesContext;
    FReady: TEvent;
    FThread: TThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

constructor TServerHarness.Create;
begin
  inherited;
  FQueue := TJobQueue.Create(20);
  FFake := TFakeUpscaler.Create;
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
  FQueue.StartWorkers(1, FFake, TPath.Combine(ProjectRoot, 'var\results_smoke'));
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

procedure TSmokeTests.Healthz_Returns200OkText;
var
  LHarness: TServerHarness;
  LResp: IHTTPResponse;
begin
  LHarness := TServerHarness.Create;
  try
    LHarness.Start;
    try
      LResp := HttpGet('/healthz');
      Assert.AreEqual(200, LResp.StatusCode);
      Assert.AreEqual('ok', Trim(LResp.ContentAsString));
    finally
      LHarness.Stop;
    end;
  finally
    LHarness.Free;
  end;
end;

procedure TSmokeTests.GetIndex_Returns200WithUploadForm;
var
  LHarness: TServerHarness;
  LResp: IHTTPResponse;
  LBody: string;
begin
  LHarness := TServerHarness.Create;
  try
    LHarness.Start;
    try
      LResp := HttpGet('/');
      Assert.AreEqual(200, LResp.StatusCode);
      LBody := LResp.ContentAsString;
      Assert.Contains(LBody, 'hx-post="/upscale"');
      Assert.Contains(LBody, 'name="resolution"');
    finally
      LHarness.Stop;
    end;
  finally
    LHarness.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSmokeTests);

end.
