unit IUS.Tests.JobQueue;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TJobQueueTests = class
  public
    [Test] procedure Enqueue_AssignsId_AndReturnsQueuedJob;
    [Test] procedure Enqueue_StoresResolution_AndIsRetrievable;
    [Test] procedure Dequeue_ReturnsNothing_WhenEmpty;
    [Test] procedure Dequeue_ReturnsFifoOrder;
    [Test] procedure Bounded_RejectsOver20;
    [Test] procedure SetStatus_UpdatesJobInPlace;
    [Test] procedure ConcurrentEnqueue_AllSucceedUpToCap;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  IUS.Upscaler.Intf,
  IUS.JobQueue;

function MakeJob(const AQueue: TJobQueue): TGuid;
var
  LJob: TJob;
begin
  Assert.IsTrue(AQueue.TryEnqueue(
    'image/png', '/tmp/x.png', TUpscaleResolution.Res2K, LJob));
  Result := LJob.Id;
end;

procedure TJobQueueTests.Enqueue_AssignsId_AndReturnsQueuedJob;
var
  LQueue: TJobQueue;
  LJob: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    Assert.IsTrue(LQueue.TryEnqueue('image/png', '/tmp/a.png',
      TUpscaleResolution.Res2K, LJob));
    Assert.AreNotEqual('{00000000-0000-0000-0000-000000000000}', LJob.Id.ToString);
    Assert.AreEqual(Ord(TJobStatus.Queued), Ord(LJob.Status));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.Enqueue_StoresResolution_AndIsRetrievable;
var
  LQueue: TJobQueue;
  LJob, LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    Assert.IsTrue(LQueue.TryEnqueue('image/png', '/tmp/a.png',
      TUpscaleResolution.Res4K, LJob));
    Assert.IsTrue(LQueue.TryGet(LJob.Id, LFetched));
    Assert.AreEqual(Ord(TUpscaleResolution.Res4K), Ord(LFetched.Resolution));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.Dequeue_ReturnsNothing_WhenEmpty;
var
  LQueue: TJobQueue;
  LJob: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    Assert.IsFalse(LQueue.TryDequeue(LJob));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.Dequeue_ReturnsFifoOrder;
var
  LQueue: TJobQueue;
  LId1, LId2: TGuid;
  LDequeued: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId1 := MakeJob(LQueue);
    LId2 := MakeJob(LQueue);
    Assert.IsTrue(LQueue.TryDequeue(LDequeued));
    Assert.AreEqual(LId1.ToString, LDequeued.Id.ToString);
    Assert.IsTrue(LQueue.TryDequeue(LDequeued));
    Assert.AreEqual(LId2.ToString, LDequeued.Id.ToString);
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.Bounded_RejectsOver20;
var
  LQueue: TJobQueue;
  LJob: TJob;
  I: Integer;
begin
  LQueue := TJobQueue.Create(20);
  try
    for I := 1 to 20 do
      Assert.IsTrue(LQueue.TryEnqueue('image/png', '/tmp/x.png',
        TUpscaleResolution.Res2K, LJob));
    Assert.IsFalse(LQueue.TryEnqueue('image/png', '/tmp/x.png',
      TUpscaleResolution.Res2K, LJob));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.SetStatus_UpdatesJobInPlace;
var
  LQueue: TJobQueue;
  LId: TGuid;
  LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId := MakeJob(LQueue);
    LQueue.SetStatus(LId, TJobStatus.Running);
    Assert.IsTrue(LQueue.TryGet(LId, LFetched));
    Assert.AreEqual(Ord(TJobStatus.Running), Ord(LFetched.Status));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.ConcurrentEnqueue_AllSucceedUpToCap;
var
  LQueue: TJobQueue;
  LCount: Integer;
begin
  LQueue := TJobQueue.Create(50);
  try
    LCount := 0;
    TParallel.&For(1, 30,
      procedure(I: Integer)
      var LJob: TJob;
      begin
        if LQueue.TryEnqueue('image/png', '/tmp/x.png',
          TUpscaleResolution.Res2K, LJob) then
          TInterlocked.Increment(LCount);
      end);
    Assert.AreEqual(30, LCount);
  finally
    LQueue.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TJobQueueTests);

end.
