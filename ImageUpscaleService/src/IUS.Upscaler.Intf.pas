{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Single-method interface that hides whether upscaling is done via raw
  ///   HTTPS, the MaxiDonkey/DelphiGemini wrapper, or a test fake.
  /// </summary>
  /// <remarks>
  ///   The orchestrator (worker pool) only ever sees IUpscaler. Errors are
  ///   surfaced as EUpscalerError subclasses; the route layer maps each
  ///   subclass to a user-facing message (see PRD section 4.6).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Upscaler.Intf;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  /// <summary>Output resolution requested via Nano Banana Pro's `imageSize`.</summary>
  TUpscaleResolution = (Res1K, Res2K, Res4K);

  /// <summary>Base class for any upscaler failure surfaced to the worker.</summary>
  EUpscalerError = class(Exception);
  EUpscalerNetworkError = class(EUpscalerError);
  EUpscalerRejectedError = class(EUpscalerError);
  EUpscalerQuotaError = class(EUpscalerError);
  EUpscalerServerError = class(EUpscalerError);
  EUpscalerEmptyResultError = class(EUpscalerError);

  IUpscaler = interface
    ['{A4B7C2E0-1D3F-4F84-9B0A-9F2C5C0E8E10}']
    /// <summary>Sends ASource (with declared ASourceMime) to the upscaler at
    ///   AResolution and returns the remastered PNG bytes. Raises an
    ///   EUpscalerError subclass on any failure.</summary>
    function Upscale(const ASource: TBytes;
                     const ASourceMime: string;
                     const AResolution: TUpscaleResolution): TBytes;
  end;

/// <summary>Maps the resolution enum to the API string ('1K' / '2K' / '4K').</summary>
function ResolutionToApiString(const AResolution: TUpscaleResolution): string;

implementation

function ResolutionToApiString(const AResolution: TUpscaleResolution): string;
begin
  case AResolution of
    TUpscaleResolution.Res1K: Result := '1K';
    TUpscaleResolution.Res2K: Result := '2K';
    TUpscaleResolution.Res4K: Result := '4K';
  else
    Result := '2K';
  end;
end;

end.
