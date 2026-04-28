{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Orchestrator that processes a dropped batch of paths: parses dates
  ///   from filenames and delegates timestamp writes to an IFileTimeSetter.
  /// </summary>
  /// <remarks>
  ///   - Walks dropped paths: directories are enumerated top-level only.
  ///   - Per-platform access-denied codes are detected (ERROR_ACCESS_DENIED
  ///     on Windows, EACCES on macOS) and counted as Skipped, not errors.
  ///   - Other failures are appended to a per-user error log.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Service;

interface

uses
  System.SysUtils, System.Classes,
  DX.DateChanger.FileTime;

type
  TDropResult = record
    Processed: Integer;
    Skipped:   Integer;
    Errors:    Integer;
    LogPath:   string;
  end;

  TDateChangerService = class
  private
    FTimeSetter: IFileTimeSetter;
    FLogPath: string;
    function GetLogPath: string;
    procedure AppendErrorLog(const APath: string; AErrorCode: Integer; const AMessage: string);
    procedure ProcessOneFile(const APath: string; var AResult: TDropResult);
    function IsAccessDenied(AOSErrorCode: Integer): Boolean;
  public
    constructor Create(const ATimeSetter: IFileTimeSetter);
    function ProcessDrop(const APaths: TArray<string>): TDropResult;
  end;

implementation

uses
  System.DateUtils, System.IOUtils,
  DX.DateChanger.Parser
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF}
  {$IFDEF POSIX}, Posix.Errno{$ENDIF};

const
{$IFDEF MSWINDOWS}
  cAccessDeniedCode = ERROR_ACCESS_DENIED;
{$ELSE}
  cAccessDeniedCode = EACCES;
{$ENDIF}

{ TDateChangerService }

constructor TDateChangerService.Create(const ATimeSetter: IFileTimeSetter);
begin
  inherited Create;
  FTimeSetter := ATimeSetter;
end;

function TDateChangerService.IsAccessDenied(AOSErrorCode: Integer): Boolean;
begin
  Result := AOSErrorCode = cAccessDeniedCode;
end;

function TDateChangerService.GetLogPath: string;
var
  LDir: string;
begin
  if FLogPath <> '' then
    Exit(FLogPath);
{$IFDEF MSWINDOWS}
  LDir := TPath.Combine(TPath.GetHomePath, 'DX.DateChanger');
{$ENDIF}
{$IFDEF MACOS}
  LDir := TPath.Combine(TPath.Combine(TPath.GetLibraryPath, 'Application Support'), 'DX.DateChanger');
{$ENDIF}
  TDirectory.CreateDirectory(LDir);
  FLogPath := TPath.Combine(LDir, 'errors.log');
  Result := FLogPath;
end;

procedure TDateChangerService.AppendErrorLog(const APath: string; AErrorCode: Integer; const AMessage: string);
var
  LStream: TStreamWriter;
  LLine: string;
begin
  LLine := Format('%s'#9'%s'#9'%d'#9'%s',
    [DateToISO8601(Now, False), APath, AErrorCode, AMessage]);
  LStream := TFile.AppendText(GetLogPath);
  try
    LStream.WriteLine(LLine);
  finally
    LStream.Free;
  end;
end;

procedure TDateChangerService.ProcessOneFile(const APath: string; var AResult: TDropResult);
var
  LParse: TParseResult;
  LWhen: TDateTime;
begin
  if not TFile.Exists(APath) then
  begin
    Inc(AResult.Errors);
    AppendErrorLog(APath, 0, 'File not found');
    Exit;
  end;

  LParse := TryParseFilenameDate(APath);
  if not LParse.Matched then
  begin
    Inc(AResult.Skipped);
    Exit;
  end;

  LWhen := LParse.Date + EncodeTime(10, 0, 0, 0);
  try
    FTimeSetter.SetTimes(APath, LWhen);
    Inc(AResult.Processed);
  except
    on E: EFileTimeError do
    begin
      if IsAccessDenied(E.OSErrorCode) then
        Inc(AResult.Skipped)
      else
      begin
        Inc(AResult.Errors);
        AppendErrorLog(APath, E.OSErrorCode, E.Message);
      end;
    end;
  end;
end;

function TDateChangerService.ProcessDrop(const APaths: TArray<string>): TDropResult;
var
  LPath: string;
  LFile: string;
begin
  Result := Default(TDropResult);

  for LPath in APaths do
  begin
    if TDirectory.Exists(LPath) then
    begin
      for LFile in TDirectory.GetFiles(LPath) do
        ProcessOneFile(LFile, Result);
    end
    else
      ProcessOneFile(LPath, Result);
  end;

  if Result.Errors > 0 then
    Result.LogPath := GetLogPath;
end;

end.