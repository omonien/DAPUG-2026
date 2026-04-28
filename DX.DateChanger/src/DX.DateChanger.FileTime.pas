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

constructor EFileTimeError.Create(const AMessage: string; AOSErrorCode: Integer);
begin
  inherited Create(AMessage);
  Self.OSErrorCode := AOSErrorCode;
end;

function CreateFileTimeSetter: IFileTimeSetter;
begin
  raise ENotImplemented.Create('CreateFileTimeSetter: no implementation yet');
end;

end.