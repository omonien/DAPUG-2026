{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Bounded FIFO job queue with thread-safe enqueue/dequeue and a
  ///   GUID-keyed dictionary for status updates and lookups.
  /// </summary>
  /// <remarks>
  ///   Worker threads are added in Task 14 (StartWorkers / StopWorkers).
  ///   The data structure is intentionally usable on its own so it can be
  ///   tested without spinning up threads.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.JobQueue;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  IUS.Upscaler.Intf,
  IUS.Describer.Intf;

type
  TJobStatus = (Queued, Running, Done, Error);

  TDescribeStatus = (NotRequested, Running, Done, Failed);

  TJob = record
    Id: TGuid;
    Status: TJobStatus;
    CreatedAt: TDateTime;
    SourceMime: string;
    SourcePath: string;
    ResultPath: string;
    Resolution: TUpscaleResolution;
    ErrorMsg: string;
    DescribeStatus:  TDescribeStatus;
    DescribeTitle:   string;
    DescribeCaption: string;
  end;

  TJobQueue = class
  strict private
    FCap: Integer;
    FLock: TCriticalSection;
    FByOrder: TQueue<TGuid>;
    FById: TDictionary<TGuid, TJob>;
    FWorkers: TArray<TThread>;
    FRunning: Boolean;
    FUpscaler: IUpscaler;
    FDescriber: IDescriber;
    FResultDir: string;
    FCleanup: TThread;
    FCleanupInterval: Integer;
    FRetentionMinutes: Integer;
    FUploadDir: string;
  public
    constructor Create(const ACap: Integer);
    destructor Destroy; override;

    function TryEnqueue(const ASourceMime, ASourcePath: string;
                        const AResolution: TUpscaleResolution;
                        out AJob: TJob): Boolean;
    function TryDequeue(out AJob: TJob): Boolean;
    function TryGet(const AId: TGuid; out AJob: TJob): Boolean;
    procedure SetStatus(const AId: TGuid; const AStatus: TJobStatus);
    procedure SetError(const AId: TGuid; const AMessage: string);
    procedure SetResult(const AId: TGuid; const AResultPath: string);
    procedure SetDescribeRunning(const AId: TGuid);
    procedure SetDescribeDone(const AId: TGuid; const ATitle, ACaption: string);
    procedure SetDescribeFailed(const AId: TGuid);
    function DeleteJob(const AId: TGuid): Boolean;
    function Count: Integer;

    procedure StartWorkers(const ACount: Integer;
                           const AUpscaler:  IUpscaler;
                           const ADescriber: IDescriber;
                           const AResultDir: string);
    procedure StopWorkers;

    procedure StartCleanup(const AUploadDir: string;
                           const ARetentionMinutes: Integer;
                           const AIntervalMs: Integer = 5 * 60 * 1000);
    procedure StopCleanup;
    /// <summary>Performs one sweep pass synchronously. Public for tests.</summary>
    procedure SweepOnce(const ANow: TDateTime);
  end;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  IUS.Storage;

function UserMessageForUpscaleError(const E: Exception): string;
begin
  if E is EUpscalerNetworkError then
    Result := 'Upscale service unreachable. Try again.'
  else if E is EUpscalerRejectedError then
    Result := 'Image rejected by upscale service.'
  else if E is EUpscalerQuotaError then
    Result := 'Daily quota reached. Try again later.'
  else if E is EUpscalerServerError then
    Result := 'Upscale service temporarily unavailable.'
  else if E is EUpscalerEmptyResultError then
    Result := 'Upscale service returned no image.'
  else
    Result := 'Upscale failed. Try again.';
end;

constructor TJobQueue.Create(const ACap: Integer);
begin
  inherited Create;
  FCap := ACap;
  FLock := TCriticalSection.Create;
  FByOrder := TQueue<TGuid>.Create;
  FById := TDictionary<TGuid, TJob>.Create;
end;

destructor TJobQueue.Destroy;
begin
  FById.Free;
  FByOrder.Free;
  FLock.Free;
  inherited;
end;

function TJobQueue.TryEnqueue(const ASourceMime, ASourcePath: string;
                              const AResolution: TUpscaleResolution;
                              out AJob: TJob): Boolean;
begin
  FLock.Enter;
  try
    if FById.Count >= FCap then Exit(False);
    AJob := Default(TJob);
    AJob.Id := TGuid.NewGuid;
    AJob.Status := TJobStatus.Queued;
    AJob.CreatedAt := Now;
    AJob.SourceMime := ASourceMime;
    AJob.SourcePath := ASourcePath;
    AJob.Resolution := AResolution;
    FById.Add(AJob.Id, AJob);
    FByOrder.Enqueue(AJob.Id);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TJobQueue.TryDequeue(out AJob: TJob): Boolean;
var
  LId: TGuid;
begin
  FLock.Enter;
  try
    if FByOrder.Count = 0 then Exit(False);
    LId := FByOrder.Dequeue;
    Result := FById.TryGetValue(LId, AJob);
  finally
    FLock.Leave;
  end;
end;

function TJobQueue.TryGet(const AId: TGuid; out AJob: TJob): Boolean;
begin
  FLock.Enter;
  try
    Result := FById.TryGetValue(AId, AJob);
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetStatus(const AId: TGuid; const AStatus: TJobStatus);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.Status := AStatus;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetError(const AId: TGuid; const AMessage: string);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.Status := TJobStatus.Error;
      LJob.ErrorMsg := AMessage;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetResult(const AId: TGuid; const AResultPath: string);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.Status := TJobStatus.Done;
      LJob.ResultPath := AResultPath;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetDescribeRunning(const AId: TGuid);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus := TDescribeStatus.Running;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetDescribeDone(const AId: TGuid; const ATitle, ACaption: string);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus  := TDescribeStatus.Done;
      LJob.DescribeTitle   := ATitle;
      LJob.DescribeCaption := ACaption;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetDescribeFailed(const AId: TGuid);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus := TDescribeStatus.Failed;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

function TJobQueue.DeleteJob(const AId: TGuid): Boolean;
var
  LJob: TJob;
begin
  Result := False;
  LJob := Default(TJob);
  FLock.Enter;
  try
    if not FById.TryGetValue(AId, LJob) then
      Exit(False);
    FById.Remove(AId);
    Result := True;
  finally
    FLock.Leave;
  end;

  if (LJob.SourcePath <> '') and TFile.Exists(LJob.SourcePath) then
    TFile.Delete(LJob.SourcePath);
  if (LJob.ResultPath <> '') and TFile.Exists(LJob.ResultPath) then
    TFile.Delete(LJob.ResultPath);
end;

function TJobQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FById.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.StartWorkers(const ACount: Integer;
                                 const AUpscaler:  IUpscaler;
                                 const ADescriber: IDescriber;
                                 const AResultDir: string);
var
  I: Integer;
begin
  FUpscaler := AUpscaler;
  FDescriber := ADescriber;
  FResultDir := AResultDir;
  IUS.Storage.EnsureDirectory(FResultDir);
  FRunning := True;
  SetLength(FWorkers, ACount);
  for I := 0 to ACount - 1 do
    FWorkers[I] := TThread.CreateAnonymousThread(
      procedure
      var LJob: TJob; LSource, LResult: TBytes; LResultPath: string;
      begin
        while FRunning do
        begin
          if TryDequeue(LJob) then
          try
            Writeln(Format('job=%s queued->running', [Copy(LJob.Id.ToString, 2, 8)]));
            SetStatus(LJob.Id, TJobStatus.Running);
            LSource := IUS.Storage.ReadAllBytes(LJob.SourcePath);
            LResult := FUpscaler.Upscale(LSource, LJob.SourceMime, LJob.Resolution);
            LResultPath := TPath.Combine(FResultDir, LJob.Id.ToString + '.png');
            IUS.Storage.WriteAllBytes(LResultPath, LResult);
            SetResult(LJob.Id, LResultPath);
            Writeln(Format('job=%s running->done', [Copy(LJob.Id.ToString, 2, 8)]));

            // Fire-and-forget describer. Status flips to Running so the
            // /describe/:id route can show the polling fragment immediately.
            // The describe thread is anonymous (FreeOnTerminate := True by
            // default) and reads the result PNG from disk so it does not pin
            // the upscale's working buffers.
            SetDescribeRunning(LJob.Id);
            TThread.CreateAnonymousThread(
              procedure
              var LDesc: TDescription; LBytes: TBytes;
              begin
                try
                  LBytes := IUS.Storage.ReadAllBytes(LResultPath);
                  LDesc  := FDescriber.Describe(LBytes, 'image/png');
                  SetDescribeDone(LJob.Id, LDesc.Title, LDesc.Caption);
                except
                  on E: Exception do
                  begin
                    SetDescribeFailed(LJob.Id);
                    Writeln(Format('job=%s describe failed: %s',
                      [Copy(LJob.Id.ToString, 2, 8), E.Message]));
                  end;
                end;
              end).Start;
          except
            on E: Exception do
            begin
              SetError(LJob.Id, UserMessageForUpscaleError(E));
              Writeln(Format('job=%s running->error: %s',
                [Copy(LJob.Id.ToString, 2, 8), E.Message]));
            end;
          end
          else
            Sleep(50);
        end;
      end);
  for I := 0 to ACount - 1 do
  begin
    FWorkers[I].FreeOnTerminate := False;
    FWorkers[I].Start;
  end;
end;

procedure TJobQueue.StopWorkers;
var T: TThread;
begin
  FRunning := False;
  for T in FWorkers do
  begin
    T.WaitFor;
    T.Free;
  end;
  SetLength(FWorkers, 0);
end;

procedure TJobQueue.StartCleanup(const AUploadDir: string;
                                 const ARetentionMinutes: Integer;
                                 const AIntervalMs: Integer);
begin
  FUploadDir := AUploadDir;
  FRetentionMinutes := ARetentionMinutes;
  FCleanupInterval := AIntervalMs;
  FCleanup := TThread.CreateAnonymousThread(
    procedure
    begin
      while FRunning do
      begin
        SweepOnce(Now);
        Sleep(FCleanupInterval);
      end;
    end);
  FCleanup.FreeOnTerminate := False;
  FCleanup.Start;
end;

procedure TJobQueue.StopCleanup;
begin
  if Assigned(FCleanup) then
  begin
    FCleanup.WaitFor;
    FCleanup.Free;
    FCleanup := nil;
  end;
end;

procedure TJobQueue.SweepOnce(const ANow: TDateTime);
var
  LExpired: TArray<TGuid>;
  LId: TGuid;
  LJob: TJob;
  LIds: TArray<TGuid>;
  I: Integer;
begin
  FLock.Enter;
  try
    LIds := FById.Keys.ToArray;
  finally
    FLock.Leave;
  end;
  SetLength(LExpired, 0);
  for I := 0 to High(LIds) do
    if TryGet(LIds[I], LJob) and IUS.Storage.ShouldDelete(LJob.CreatedAt, FRetentionMinutes, ANow) then
    begin
      SetLength(LExpired, Length(LExpired) + 1);
      LExpired[High(LExpired)] := LIds[I];
    end;
  for LId in LExpired do
  begin
    DeleteJob(LId);
  end;
end;

end.
