{ -----------------------------------------------------------------------------
  /// <summary>
  ///   On-disk storage helpers for upload/result bytes plus the sweep
  ///   predicate used by the periodic cleanup thread.
  /// </summary>
  /// <remarks>
  ///   Pure functions and TFile.WriteAllBytes / ReadAllBytes wrappers
  ///   tagged with our error type. The cleanup *thread* lives in
  ///   IUS.JobQueue and uses ShouldDelete here as its predicate.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Storage;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.DateUtils;

type
  EStorageError = class(Exception);

/// <summary>True if a job created at ACreatedAt is older than ARetentionMinutes
///   measured against ANow.</summary>
function ShouldDelete(const ACreatedAt: TDateTime;
                      const ARetentionMinutes: Integer;
                      const ANow: TDateTime): Boolean;

procedure WriteAllBytes(const APath: string; const AData: TBytes);
function ReadAllBytes(const APath: string): TBytes;

procedure EnsureDirectory(const APath: string);

implementation

function ShouldDelete(const ACreatedAt: TDateTime;
                      const ARetentionMinutes: Integer;
                      const ANow: TDateTime): Boolean;
begin
  Result := MinutesBetween(ANow, ACreatedAt) > ARetentionMinutes;
end;

procedure WriteAllBytes(const APath: string; const AData: TBytes);
begin
  try
    TFile.WriteAllBytes(APath, AData);
  except
    on E: Exception do
      raise EStorageError.CreateFmt('Write failed for %s: %s', [APath, E.Message]);
  end;
end;

function ReadAllBytes(const APath: string): TBytes;
begin
  try
    Result := TFile.ReadAllBytes(APath);
  except
    on E: Exception do
      raise EStorageError.CreateFmt('Read failed for %s: %s', [APath, E.Message]);
  end;
end;

procedure EnsureDirectory(const APath: string);
begin
  if not TDirectory.Exists(APath) then
    TDirectory.CreateDirectory(APath);
end;

end.
