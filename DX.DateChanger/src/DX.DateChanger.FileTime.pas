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

function CreateFileTimeSetter: IFileTimeSetter;
begin
{$IFDEF MSWINDOWS}
  Result := TWinFileTimeSetter.Create;
{$ELSE}
  raise ENotImplemented.Create('CreateFileTimeSetter: macOS impl pending (Task 6)');
{$ENDIF}
end;

end.