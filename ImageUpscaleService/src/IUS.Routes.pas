{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Horse route handlers wired to the job queue and the template renderer.
  /// </summary>
  /// <remarks>
  ///   Six routes: GET /, POST /upscale, GET /jobs/:id, GET /original/:id,
  ///   GET /result/:id, GET /healthz, plus a static-file handler for /static/*.
  ///
  ///   Templates are rendered with Web.Stencils. The full page (index.html)
  ///   opts into the master layout via the @LayoutPage directive; layout.html
  ///   exposes the slot via @RenderBody. HTMX fragment templates (job_pending,
  ///   job_done, job_error) intentionally omit @LayoutPage so they render as
  ///   bare HTML for hx-swap.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Routes;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Web.HTTPApp,
  Web.Stencils,
  Horse,
  IUS.JobQueue, IUS.Validation, IUS.Upscaler.Intf, IUS.Storage;

type
  TRoutesContext = class
  private
    FQueue: TJobQueue;
    FTemplateDir: string;
    FStaticDir: string;
    FUploadDir: string;
    FResultDir: string;
    FEngine: TWebStencilsEngine;
    function RenderPage(const ATemplateName: string;
                        const AVars: array of string): string;
    function RenderError(const AMessage: string): string;
    function RenderPending(const AJob: TJob): string;
    function RenderDone(const AJob: TJob): string;
    function RenderDescribePending(const AJob: TJob): string;
    function RenderDescribeDone(const AJob: TJob): string;
    function StatusText(const AStatus: TJobStatus): string;
    function MimeToExtension(const AMime: string): string;
    function ExtensionToMime(const AExt: string): string;
    function TryParseJobId(const AStr: string; out AId: TGuid): Boolean;
  public
    constructor Create(AQueue: TJobQueue;
                       const ATemplateDir, AStaticDir, AUploadDir, AResultDir: string);
    destructor Destroy; override;
    procedure Register;
  end;

implementation

constructor TRoutesContext.Create(AQueue: TJobQueue;
                                  const ATemplateDir, AStaticDir, AUploadDir, AResultDir: string);
begin
  inherited Create;
  FQueue := AQueue;
  FTemplateDir := ATemplateDir;
  FStaticDir := AStaticDir;
  FUploadDir := AUploadDir;
  FResultDir := AResultDir;
  FEngine := TWebStencilsEngine.Create(nil);
  FEngine.RootDirectory := FTemplateDir;
end;

destructor TRoutesContext.Destroy;
begin
  FEngine.Free;
  inherited;
end;

// Helper to register a per-request scalar variable. Lives outside RenderPage
// so each call gets its own AValue parameter on the stack — the closure
// captures that frame, avoiding the classic "all closures share the loop var"
// trap when registering several variables in a row.
procedure RegisterTemplateVar(AProc: TWebStencilsProcessor;
                              const AName, AValue: string);
begin
  AProc.AddVar(AName, nil, False,
    function(AVar: TWebStencilsDataVar; const APropName: string;
             var AOut: string): Boolean
    begin
      AOut := AValue;
      Result := True;
    end);
end;

function TRoutesContext.RenderPage(const ATemplateName: string;
                                   const AVars: array of string): string;
var
  LProc: TWebStencilsProcessor;
  I: Integer;
begin
  // Whether the layout is applied is decided by the template itself via
  // @LayoutPage. Full pages (index.html) opt in; HTMX fragments don't.
  LProc := TWebStencilsProcessor.Create(nil);
  try
    LProc.Engine := FEngine;
    LProc.InputFileName := TPath.Combine(FTemplateDir, ATemplateName);
    // AVars is a flat array: name1, value1, name2, value2, ...
    I := 0;
    while I < Length(AVars) - 1 do
    begin
      RegisterTemplateVar(LProc, AVars[I], AVars[I + 1]);
      Inc(I, 2);
    end;
    Result := LProc.Content;
  finally
    LProc.Free;
  end;
end;

function TRoutesContext.StatusText(const AStatus: TJobStatus): string;
begin
  case AStatus of
    TJobStatus.Queued:  Result := 'Queued';
    TJobStatus.Running: Result := 'Upscaling';
  else
    Result := '';
  end;
end;

function TRoutesContext.RenderError(const AMessage: string): string;
begin
  Result := RenderPage('job_error.html', ['errorText', AMessage]);
end;

function TRoutesContext.RenderPending(const AJob: TJob): string;
begin
  Result := RenderPage('job_pending.html',
    ['jobId', AJob.Id.ToString, 'statusText', StatusText(AJob.Status)]);
end;

function TRoutesContext.RenderDone(const AJob: TJob): string;
begin
  Result := RenderPage('job_done.html',
    ['jobId', AJob.Id.ToString,
     'resolutionText', ResolutionToApiString(AJob.Resolution)]);
end;

function TRoutesContext.RenderDescribePending(const AJob: TJob): string;
begin
  Result := RenderPage('describe_pending.html',
    ['jobId', AJob.Id.ToString]);
end;

function TRoutesContext.RenderDescribeDone(const AJob: TJob): string;
begin
  Result := RenderPage('describe_done.html',
    ['title',   AJob.DescribeTitle,
     'caption', AJob.DescribeCaption]);
end;

function TRoutesContext.MimeToExtension(const AMime: string): string;
begin
  if AMime = 'image/jpeg' then Result := 'jpg'
  else if AMime = 'image/png' then Result := 'png'
  else if AMime = 'image/webp' then Result := 'webp'
  else Result := 'bin';
end;

function TRoutesContext.ExtensionToMime(const AExt: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(AExt);
  if (LExt = '.jpg') or (LExt = '.jpeg') then Result := 'image/jpeg'
  else if LExt = '.png' then Result := 'image/png'
  else if LExt = '.webp' then Result := 'image/webp'
  else if LExt = '.css' then Result := 'text/css'
  else if LExt = '.js' then Result := 'application/javascript'
  else if LExt = '.ico' then Result := 'image/x-icon'
  else Result := 'application/octet-stream';
end;

function TRoutesContext.TryParseJobId(const AStr: string; out AId: TGuid): Boolean;
var
  L: string;
begin
  // Accept both {GUID} (what TGuid.ToString and our templates produce in URLs)
  // and bare GUID forms.
  L := AStr;
  if (Length(L) > 0) and (L[1] <> '{') then
    L := '{' + L + '}';
  try
    AId := TGuid.Create(L);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TRoutesContext.Register;
var
  LSelf: TRoutesContext;
begin
  LSelf := Self;

  THorse.Get('/healthz',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('ok');
    end);

  THorse.Get('/',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send(LSelf.RenderPage('index.html', []));
    end);

  THorse.Post('/upscale',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LRaw: TWebRequest;
      LFile: TStream;
      LBytes: TBytes;
      LMime, LResStr, LSrcPath: string;
      LRes: TUpscaleResolution;
      LJob: TJob;
    begin
      LRaw := Req.RawWebRequest;
      if LRaw.Files.Count = 0 then
      begin
        Res.Status(422).Send(LSelf.RenderError('No file selected.'));
        Exit;
      end;
      LFile := LRaw.Files[0].Stream;
      LMime := LRaw.Files[0].ContentType;
      LFile.Position := 0;
      SetLength(LBytes, LFile.Size);
      if LFile.Size > 0 then
        LFile.Read(LBytes[0], Length(LBytes));

      if not IsSizeAccepted(Length(LBytes)) then
      begin
        Res.Status(413).Send(LSelf.RenderError('File too large (max 10 MB).'));
        Exit;
      end;
      if not IsMimeAccepted(LMime) then
      begin
        Res.Status(415).Send(LSelf.RenderError('Unsupported format. Use JPEG, PNG, or WebP.'));
        Exit;
      end;
      if not MagicBytesMatchMime(LBytes, LMime) then
      begin
        Res.Status(415).Send(LSelf.RenderError('File does not look like a real image.'));
        Exit;
      end;

      LResStr := LRaw.ContentFields.Values['resolution'];
      if not TryParseResolution(LResStr, LRes) then
      begin
        Res.Status(422).Send(LSelf.RenderError('Invalid resolution.'));
        Exit;
      end;

      EnsureDirectory(LSelf.FUploadDir);
      LSrcPath := TPath.Combine(LSelf.FUploadDir,
        TGuid.NewGuid.ToString + '.' + LSelf.MimeToExtension(LMime));
      WriteAllBytes(LSrcPath, LBytes);

      if not LSelf.FQueue.TryEnqueue(LMime, LSrcPath, LRes, LJob) then
      begin
        Res.Status(503).Send(LSelf.RenderError('Server busy. Try again in a moment.'));
        Exit;
      end;

      Res.Send(LSelf.RenderPending(LJob));
    end);

  THorse.Get('/jobs/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LId: TGuid;
      LJob: TJob;
    begin
      if not LSelf.TryParseJobId(Req.Params['id'], LId) then
      begin
        Res.Status(404).Send(LSelf.RenderError('Unknown job.'));
        Exit;
      end;
      if not LSelf.FQueue.TryGet(LId, LJob) then
      begin
        Res.Status(404).Send(LSelf.RenderError('Unknown job.'));
        Exit;
      end;
      case LJob.Status of
        TJobStatus.Queued, TJobStatus.Running: Res.Send(LSelf.RenderPending(LJob));
        TJobStatus.Done:                       Res.Send(LSelf.RenderDone(LJob));
        TJobStatus.Error:                      Res.Send(LSelf.RenderError(LJob.ErrorMsg));
      end;
    end);

  THorse.Get('/original/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LId: TGuid;
      LJob: TJob;
    begin
      if not LSelf.TryParseJobId(Req.Params['id'], LId) then
      begin
        Res.Status(404).Send('Unknown');
        Exit;
      end;
      if (not LSelf.FQueue.TryGet(LId, LJob)) or (LJob.SourcePath = '') or
         (not TFile.Exists(LJob.SourcePath)) then
      begin
        Res.Status(404).Send('Expired');
        Exit;
      end;
      Res.SendFile(LJob.SourcePath, LJob.SourceMime);
    end);

  THorse.Get('/result/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LId: TGuid;
      LJob: TJob;
    begin
      if not LSelf.TryParseJobId(Req.Params['id'], LId) then
      begin
        Res.Status(404).Send('Unknown');
        Exit;
      end;
      if (not LSelf.FQueue.TryGet(LId, LJob)) or (LJob.Status <> TJobStatus.Done) or
         (not TFile.Exists(LJob.ResultPath)) then
      begin
        Res.Status(404).Send('Not ready or expired');
        Exit;
      end;
      Res.SendFile(LJob.ResultPath, 'image/png');
    end);

  THorse.Get('/describe/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LId: TGuid;
      LJob: TJob;
    begin
      if not LSelf.TryParseJobId(Req.Params['id'], LId) then
      begin
        Res.Status(404).Send('');
        Exit;
      end;
      if not LSelf.FQueue.TryGet(LId, LJob) then
      begin
        Res.Status(404).Send('');
        Exit;
      end;
      case LJob.DescribeStatus of
        TDescribeStatus.NotRequested,
        TDescribeStatus.Running:
          Res.Send(LSelf.RenderDescribePending(LJob));
        TDescribeStatus.Done:
          Res.Send(LSelf.RenderDescribeDone(LJob));
        TDescribeStatus.Failed:
          Res.Send(''); // empty body collapses the slot, silent fail.
      end;
    end);

  THorse.Get('/static/:filename',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LName, LPath, LExt: string;
    begin
      LName := Req.Params['filename'];
      // Reject path traversal attempts
      if (Pos('..', LName) > 0) or (Pos('/', LName) > 0) or (Pos('\', LName) > 0) then
      begin
        Res.Status(400).Send('Bad request');
        Exit;
      end;
      LPath := TPath.Combine(LSelf.FStaticDir, LName);
      if not TFile.Exists(LPath) then
      begin
        Res.Status(404).Send('Not found');
        Exit;
      end;
      LExt := TPath.GetExtension(LPath);
      Res.SendFile(LPath, LSelf.ExtensionToMime(LExt));
    end);
end;

end.
