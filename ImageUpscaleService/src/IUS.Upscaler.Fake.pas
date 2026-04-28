{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Test double for IUpscaler. Returns a tiny canned 1x1 PNG and counts
  ///   the number of calls made.
  /// </summary>
  /// <remarks>
  ///   Used by every unit test and the integration smoke test. Never makes
  ///   network calls. The canned PNG is the smallest valid 1x1 transparent
  ///   PNG (67 bytes).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Upscaler.Fake;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  IUS.Upscaler.Intf;

type
  TFakeUpscaler = class(TInterfacedObject, IUpscaler)
  strict private
    FCallCount: Integer;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    function Upscale(const ASource: TBytes;
                     const ASourceMime: string;
                     const AResolution: TUpscaleResolution): TBytes;
    property CallCount: Integer read FCallCount;
  end;

implementation

const
  // Smallest valid 1x1 transparent PNG.
  cCannedPng: array[0..66] of Byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52,
    $00, $00, $00, $01, $00, $00, $00, $01, $08, $06, $00, $00, $00, $1F, $15, $C4,
    $89, $00, $00, $00, $0D, $49, $44, $41, $54, $78, $9C, $63, $00, $01, $00, $00,
    $05, $00, $01, $0D, $0A, $2D, $B4, $00, $00, $00, $00, $49, $45, $4E, $44, $AE,
    $42, $60, $82
  );

constructor TFakeUpscaler.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TFakeUpscaler.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TFakeUpscaler.Upscale(const ASource: TBytes;
                               const ASourceMime: string;
                               const AResolution: TUpscaleResolution): TBytes;
begin
  FLock.Enter;
  try
    Inc(FCallCount);
  finally
    FLock.Leave;
  end;
  SetLength(Result, Length(cCannedPng));
  Move(cCannedPng[0], Result[0], Length(cCannedPng));
end;

end.
