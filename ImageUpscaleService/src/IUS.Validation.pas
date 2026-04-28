{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Pure validation helpers for upload size, declared MIME, magic-byte
  ///   sniffing, and the resolution form field.
  /// </summary>
  /// <remarks>
  ///   No I/O, no globals. Every function returns a boolean / parse result.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Validation;

interface

uses
  System.SysUtils,
  IUS.Upscaler.Intf;

const
  /// <summary>Maximum accepted upload size in bytes (10 MB).</summary>
  cMaxUploadBytes = 10 * 1024 * 1024;

function IsSizeAccepted(const ASize: Int64): Boolean;
function IsMimeAccepted(const AMime: string): Boolean;
function MagicBytesMatchMime(const AData: TBytes; const AMime: string): Boolean;
function TryParseResolution(const AInput: string; out AResolution: TUpscaleResolution): Boolean;

implementation

function IsSizeAccepted(const ASize: Int64): Boolean;
begin
  Result := (ASize >= 0) and (ASize <= cMaxUploadBytes);
end;

function IsMimeAccepted(const AMime: string): Boolean;
begin
  Result := (AMime = 'image/jpeg') or (AMime = 'image/png') or (AMime = 'image/webp');
end;

function MagicBytesMatchMime(const AData: TBytes; const AMime: string): Boolean;
const
  cPngSig: array[0..7] of Byte  = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
  cJpegSig: array[0..2] of Byte = ($FF, $D8, $FF);
  cRiffSig: array[0..3] of Byte = ($52, $49, $46, $46);
  cWebpSig: array[0..3] of Byte = ($57, $45, $42, $50);
var
  I: Integer;
  LMatch: Boolean;
begin
  if AMime = 'image/png' then
  begin
    if Length(AData) < Length(cPngSig) then Exit(False);
    for I := 0 to High(cPngSig) do
      if AData[I] <> cPngSig[I] then Exit(False);
    Exit(True);
  end;
  if AMime = 'image/jpeg' then
  begin
    if Length(AData) < Length(cJpegSig) then Exit(False);
    for I := 0 to High(cJpegSig) do
      if AData[I] <> cJpegSig[I] then Exit(False);
    Exit(True);
  end;
  if AMime = 'image/webp' then
  begin
    if Length(AData) < 12 then Exit(False);
    LMatch := True;
    for I := 0 to 3 do if AData[I] <> cRiffSig[I] then begin LMatch := False; Break; end;
    if LMatch then
      for I := 0 to 3 do if AData[I + 8] <> cWebpSig[I] then begin LMatch := False; Break; end;
    Exit(LMatch);
  end;
  Result := False;
end;

function TryParseResolution(const AInput: string; out AResolution: TUpscaleResolution): Boolean;
var
  L: string;
begin
  L := UpperCase(Trim(AInput));
  if L = '' then begin AResolution := TUpscaleResolution.Res2K; Exit(True); end;
  if L = '1K' then begin AResolution := TUpscaleResolution.Res1K; Exit(True); end;
  if L = '2K' then begin AResolution := TUpscaleResolution.Res2K; Exit(True); end;
  if L = '4K' then begin AResolution := TUpscaleResolution.Res4K; Exit(True); end;
  Result := False;
end;

end.
