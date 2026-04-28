{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Composition root: parses CLI, loads config, wires every collaborator,
  ///   starts the Horse listener and blocks.
  /// </summary>
  /// <remarks>
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

function FindConfigPath: string;
var
  I: Integer;
begin
  Result := 'config.ini';
  I := 1;
  while I < ParamCount do
  begin
    if SameText(ParamStr(I), '--config') then
    begin
      Result := ParamStr(I + 1);
      Exit;
    end;
    Inc(I);
  end;
end;

function BuildUpscaler(const ACfg: TConfig): IUpscaler;
begin
  if ACfg.Provider = 'native' then
    Result := TNativeUpscaler.Create(ACfg.ApiKey, ACfg.Model, cRemasterPrompt)
  else
    Result := TDelphiGeminiUpscaler.Create(ACfg.ApiKey, ACfg.Model, cRemasterPrompt);
end;

procedure RunServer;
var
  LCfg: TConfig;
  LQueue: TJobQueue;
  LRoutes: TRoutesContext;
  LUpscaler: IUpscaler;
  LConfigPath: string;
begin
  LConfigPath := FindConfigPath;
  if not TFile.Exists(LConfigPath) then
    raise Exception.CreateFmt(
      'Config file not found: %s. Copy config.ini.example to config.ini and fill in your Gemini API key.',
      [LConfigPath]);

  LCfg := LoadConfig(LConfigPath);
  Writeln(Format('Loaded remaster prompt, %d chars', [Length(cRemasterPrompt)]));

  EnsureDirectory(LCfg.UploadDir);
  EnsureDirectory(LCfg.ResultDir);

  LUpscaler := BuildUpscaler(LCfg);
  LQueue := TJobQueue.Create(20);
  LRoutes := TRoutesContext.Create(LQueue, 'templates', 'public',
    LCfg.UploadDir, LCfg.ResultDir);
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
    LQueue.StartWorkers(3, LUpscaler, LCfg.ResultDir);
    LQueue.StartCleanup(LCfg.UploadDir, LCfg.RetentionMinutes);

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
