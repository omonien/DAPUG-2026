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
  System.Generics.Collections,
  System.SyncObjs,
  IUS.Upscaler.Intf;

type
  TJobStatus = (Queued, Running, Done, Error);

  TJob = record
    Id: TGuid;
    Status: TJobStatus;
    CreatedAt: TDateTime;
    SourceMime: string;
    SourcePath: string;
    ResultPath: string;
    Resolution: TUpscaleResolution;
    ErrorMsg: string;
  end;

  TJobQueue = class
  strict private
    FCap: Integer;
    FLock: TCriticalSection;
    FByOrder: TQueue<TGuid>;
    FById: TDictionary<TGuid, TJob>;
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
    function Count: Integer;
  end;

implementation

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

function TJobQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FById.Count;
  finally
    FLock.Leave;
  end;
end;

end.
