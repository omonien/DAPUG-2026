{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IFileTimeSetter abstraction for setting creation, modification and
  ///   access timestamps on a file in a platform-independent way.
  /// </summary>
  /// <remarks>
  ///   The interface decouples the orchestrator (TDateChangerService) from
  ///   OS-specific file APIs and makes the orchestrator unit-testable with
  ///   a mock. Concrete implementations are added in a later task: Win32
  ///   uses SetFileTime; macOS uses NSFileManager + utimes.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.FileTime;

interface

uses
  System.SysUtils;

type
  EFileTimeError = class(Exception)
  public
    OSErrorCode: Integer;
    constructor Create(const AMessage: string; AOSErrorCode: Integer);
  end;

  IFileTimeSetter = interface
    ['{B9D8C5E1-3A2F-4F77-9F1B-7A2A2C3E5D11}']
    /// <summary>
    ///   Sets creation, modification and access timestamps of APath to AWhen.
    ///   Raises EFileTimeError on failure with OSErrorCode populated.
    /// </summary>
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

/// <summary>
///   Returns the platform-default IFileTimeSetter implementation. Raises
///   ENotImplemented on platforms with no implementation yet.
/// </summary>
function CreateFileTimeSetter: IFileTimeSetter;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF MACOS}
  Macapi.Foundation, Macapi.ObjectiveC, Macapi.Helpers,
  Posix.SysTime, Posix.Errno,
{$ENDIF}
  System.DateUtils;

constructor EFileTimeError.Create(const AMessage: string; AOSErrorCode: Integer);
begin
  inherited Create(AMessage);
  Self.OSErrorCode := AOSErrorCode;
end;

{$IFDEF MSWINDOWS}
type
  TWinFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  public
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

procedure TWinFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LHandle: THandle;
  LSysTime: TSystemTime;
  LFileTimeUtc: TFileTime;
  LWhenUtc: TDateTime;
  LErr: Integer;
begin
  LHandle := CreateFileW(PChar(APath), GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    LErr := GetLastError;
    raise EFileTimeError.Create('CreateFileW failed: ' + SysErrorMessage(LErr), LErr);
  end;
  try
    LWhenUtc := TTimeZone.Local.ToUniversalTime(AWhen);
    DateTimeToSystemTime(LWhenUtc, LSysTime);
    if not SystemTimeToFileTime(LSysTime, LFileTimeUtc) then
    begin
      LErr := GetLastError;
      raise EFileTimeError.Create('SystemTimeToFileTime failed', LErr);
    end;
    if not SetFileTime(LHandle, @LFileTimeUtc, @LFileTimeUtc, @LFileTimeUtc) then
    begin
      LErr := GetLastError;
      raise EFileTimeError.Create('SetFileTime failed: ' + SysErrorMessage(LErr), LErr);
    end;
  finally
    CloseHandle(LHandle);
  end;
end;
{$ENDIF}

{$IFDEF MACOS}
type
  /// <summary>
  ///   macOS implementation of IFileTimeSetter. Sets creation and modification
  ///   timestamps via NSFileManager.setAttributes and access time via POSIX utimes.
  /// </summary>
  TMacFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  public
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

procedure TMacFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LMgr: NSFileManager;
  LAttrs: NSMutableDictionary;
  LDate: NSDate;
  LWhenUtc: TDateTime;
  LIntervalSince1970: Double;
  LNSPath: NSString;
  LErrorPtr: Pointer;
  LTimes: array[0..1] of timeval;
  LCPath: MarshaledAString;
  LRC: Integer;
begin
  LWhenUtc := TTimeZone.Local.ToUniversalTime(AWhen);
  // NSDate uses seconds since 1970-01-01 00:00:00 UTC
  LIntervalSince1970 := (LWhenUtc - EncodeDate(1970, 1, 1)) * SecsPerDay;
  LDate := TNSDate.Wrap(TNSDate.OCClass.dateWithTimeIntervalSince1970(LIntervalSince1970));

  LAttrs := TNSMutableDictionary.Create;
  try
    // Use NSFileCreationDate / NSFileModificationDate constants as keys
    LAttrs.setValue(NSObjectToID(LDate), NSFileCreationDate);
    LAttrs.setValue(NSObjectToID(LDate), NSFileModificationDate);

    LMgr := TNSFileManager.Wrap(TNSFileManager.OCClass.defaultManager);
    LNSPath := StrToNSStr(APath);
    LErrorPtr := nil;
    if not LMgr.setAttributes(LAttrs, LNSPath, @LErrorPtr) then
      raise EFileTimeError.Create('NSFileManager.setAttributes failed', EACCES);

    // Set access time via POSIX utimes (NSFileManager does not expose atime).
    LCPath := MarshaledAString(UTF8String(APath));
    LTimes[0].tv_sec  := Trunc(LIntervalSince1970);
    LTimes[0].tv_usec := 0;
    LTimes[1] := LTimes[0];  // mtime mirror (already set above; belt-and-suspenders)
    LRC := utimes(LCPath, @LTimes[0]);
    if LRC <> 0 then
      raise EFileTimeError.Create('utimes failed', errno);
  finally
    LAttrs.release;
  end;
end;
{$ENDIF}

function CreateFileTimeSetter: IFileTimeSetter;
begin
{$IFDEF MSWINDOWS}
  Result := TWinFileTimeSetter.Create;
{$ELSEIF Defined(MACOS)}
  Result := TMacFileTimeSetter.Create;
{$ELSE}
  raise ENotImplemented.Create('No IFileTimeSetter for this platform');
{$ENDIF}
end;

end.