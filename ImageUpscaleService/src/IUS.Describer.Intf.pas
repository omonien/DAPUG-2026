{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Single-method interface that hides whether description is done via
  ///   raw HTTPS or a test fake.
  /// </summary>
  /// <remarks>
  ///   Mirrors the IUpscaler pattern. Exception tree maps onto the same
  ///   HTTP status code shape (network / rejected / quota / server / empty).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Intf;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  /// <summary>Title (2-5 word noun phrase) plus 1-2 sentence caption.</summary>
  TDescription = record
    Title:   string;
    Caption: string;
  end;

  /// <summary>Base class for any describer failure surfaced to the worker.</summary>
  EDescriberError            = class(Exception);
  EDescriberNetworkError     = class(EDescriberError);
  EDescriberRejectedError    = class(EDescriberError);
  EDescriberQuotaError       = class(EDescriberError);
  EDescriberServerError      = class(EDescriberError);
  EDescriberEmptyResultError = class(EDescriberError);

  IDescriber = interface
    ['{B7E1F4D2-2E8A-4B12-8C5C-9F4D8C2A1E33}']
    /// <summary>Sends AImage (with declared AImageMime) to the Flash model
    ///   and returns the parsed TDescription. Raises an EDescriberError
    ///   subclass on any failure.</summary>
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
  end;

implementation

end.
