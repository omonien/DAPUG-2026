{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Composition root: parses CLI, loads config, wires every collaborator,
  ///   starts the Horse listener and blocks.
  /// </summary>
  /// <remarks>
  ///   All asset paths (config.ini, templates/, public/) are resolved
  ///   relative to the project root, which is discovered by walking up
  ///   from the exe location until a folder containing a templates/ child
  ///   is found. This makes the server work whether you launch it from
  ///   ImageUpscaleService/ (the build/Win64/Debug/exe layout the workshop
  ///   builds), from inside the build folder, or from anywhere else.
  ///
  ///   On any startup failure (missing config, bad API key, port in use)
  ///   prints a one-line cause and exits non-zero. Once running, logs one
  ///   line per HTTP request and one line per job state transition (the
  ///   per-job logging lives in IUS.JobQueue's worker loop).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Server;

interface

procedure RunServer;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils,
  Web.HTTPApp,
  Horse,
  IUS.Config, IUS.JobQueue, IUS.Routes, IUS.Storage,
  IUS.Upscaler.Intf, IUS.Upscaler.Native, IUS.Upscaler.DelphiGemini,
  IUS.Prompt;

/// <summary>Walk up from the exe at most 5 levels until a folder containing
///   `templates/` is found. Handles both "exe is next to templates" (typical
///   distribution) and "exe is at build/Win64/Debug/" (typical workshop build).
///   Raises a clear exception if neither layout matches.</summary>
function FindProjectRoot: string;
var
  LDir: string;
  I: Integer;
begin
  LDir := ExtractFilePath(ParamStr(0));
  for I := 0 to 5 do
  begin
    if TDirectory.Exists(TPath.Combine(LDir, 'templates')) then
      Exit(IncludeTrailingPathDelimiter(LDir));
    LDir := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(LDir));
    if LDir = '' then Break;
  end;
  raise Exception.CreateFmt(
    'Could not locate templates/ near the exe (%s). ' +
    'Either run from inside ImageUpscaleService/, or copy templates/ + public/ next to the exe.',
    [ParamStr(0)]);
end;

/// <summary>If --config is given, returns that path verbatim (caller decides
///   absolute vs. relative). Otherwise returns AProjectRoot/config.ini.</summary>
function FindConfigPath(const AProjectRoot: string): string;
var
  I: Integer;
begin
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), '--config') then
      Exit(ParamStr(I + 1));
  Result := TPath.Combine(AProjectRoot, 'config.ini');
end;

function BuildUpscaler(const ACfg: TConfig): IUpscaler;
begin
  if ACfg.Provider = 'native' then
    Result := TNativeUpscaler.Create(ACfg.ApiKey, ACfg.Model, cRemasterPrompt)
  else
    Result := TDelphiGeminiUpscaler.Create(ACfg.ApiKey, ACfg.Model, cRemasterPrompt);
end;

/// <summary>Anchors a relative path under AProjectRoot. Absolute paths are
///   returned unchanged so users can point Storage at any disk location.</summary>
function ResolveStoragePath(const AProjectRoot, APath: string): string;
begin
  if TPath.IsPathRooted(APath) then
    Result := APath
  else
    Result := TPath.GetFullPath(TPath.Combine(AProjectRoot, APath));
end;

procedure RunServer;
var
  LCfg: TConfig;
  LQueue: TJobQueue;
  LRoutes: TRoutesContext;
  LUpscaler: IUpscaler;
  LRoot, LConfigPath, LUploadDir, LResultDir: string;
begin
  LRoot := FindProjectRoot;
  LConfigPath := FindConfigPath(LRoot);
  if not TFile.Exists(LConfigPath) then
    raise Exception.CreateFmt(
      'Config file not found: %s. Copy config.ini.example to config.ini and fill in your Gemini API key.',
      [LConfigPath]);

  LCfg := LoadConfig(LConfigPath);
  Writeln(Format('Loaded remaster prompt, %d chars', [Length(cRemasterPrompt)]));

  LUploadDir := ResolveStoragePath(LRoot, LCfg.UploadDir);
  LResultDir := ResolveStoragePath(LRoot, LCfg.ResultDir);
  EnsureDirectory(LUploadDir);
  EnsureDirectory(LResultDir);

  LUpscaler := BuildUpscaler(LCfg);
  LQueue := TJobQueue.Create(20);
  LRoutes := TRoutesContext.Create(LQueue,
    TPath.Combine(LRoot, 'templates'),
    TPath.Combine(LRoot, 'public'),
    LUploadDir, LResultDir);
  try
    THorse.Use(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        LStart: TDateTime;
        LPath: string;
      begin
        LStart := Now;
        LPath := Req.RawWebRequest.PathInfo;
        Next();
        Writeln(Format('%s %s -> %d (%d ms)',
          [Req.RawWebRequest.Method, LPath, Res.Status,
           MilliSecondsBetween(Now, LStart)]));
      end);

    LRoutes.Register;
    LQueue.StartWorkers(3, LUpscaler, LResultDir);
    LQueue.StartCleanup(LUploadDir, LCfg.RetentionMinutes);

    Writeln(Format('Project root:    %s', [LRoot]));
    Writeln(Format('Config:          %s', [LConfigPath]));
    Writeln(Format('Uploads / results: %s | %s', [LUploadDir, LResultDir]));
    Writeln(Format('ImageUpscaleService listening on http://localhost:%d  (upscaler=%s)',
      [LCfg.Port, LCfg.Provider]));
    THorse.Listen(LCfg.Port);
  finally
    LQueue.StopCleanup;
    LQueue.StopWorkers;
    LRoutes.Free;
    LQueue.Free;
  end;
end;

end.
