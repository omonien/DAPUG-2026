{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Test double for IDescriber. Returns a canned TDescription and counts
  ///   calls. Can be configured to raise a specific EDescriber* on the next
  ///   call to exercise the worker's silent-failure path.
  /// </summary>
  /// <remarks>
  ///   Used by every unit test and the integration smoke test. Never makes
  ///   network calls.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Fake;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  IUS.Describer.Intf;

type
  TFakeDescriber = class(TInterfacedObject, IDescriber)
  strict private
    FCallCount: Integer;
    FLock: TCriticalSection;
    FNextException: ExceptClass;
  public
    constructor Create;
    destructor Destroy; override;
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
    /// <summary>Configures the fake so the next Describe call raises
    ///   AException with a fixed message. Cleared after one use.</summary>
    procedure RaiseOnNextCall(const AException: ExceptClass);
    property CallCount: Integer read FCallCount;
  end;

implementation

constructor TFakeDescriber.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TFakeDescriber.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TFakeDescriber.Describe(const AImage: TBytes; const AImageMime: string): TDescription;
var
  LToRaise: ExceptClass;
begin
  FLock.Enter;
  try
    Inc(FCallCount);
    LToRaise := FNextException;
    FNextException := nil;
  finally
    FLock.Leave;
  end;
  if LToRaise <> nil then
    raise LToRaise.Create('fake error');
  Result.Title   := 'Test scene';
  Result.Caption := 'A canned caption returned by the fake describer for unit tests.';
end;

procedure TFakeDescriber.RaiseOnNextCall(const AException: ExceptClass);
begin
  FLock.Enter;
  try
    FNextException := AException;
  finally
    FLock.Leave;
  end;
end;

end.