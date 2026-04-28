unit IUS.Tests.Validation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TValidationTests = class
  public
    [Test] procedure Size_Below10MB_Accepted;
    [Test] procedure Size_Exactly10MB_Accepted;
    [Test] procedure Size_Above10MB_Rejected;
    [Test] procedure Mime_Jpeg_Accepted;
    [Test] procedure Mime_Png_Accepted;
    [Test] procedure Mime_Webp_Accepted;
    [Test] procedure Mime_Gif_Rejected;
    [Test] procedure Mime_Empty_Rejected;
    [Test] procedure Sniff_PngHeader_MatchesPngMime;
    [Test] procedure Sniff_JpegHeader_MatchesJpegMime;
    [Test] procedure Sniff_WebpHeader_MatchesWebpMime;
    [Test] procedure Sniff_PngHeader_DoesNotMatchJpegMime;
    [Test] procedure Res_1K_Accepted;
    [Test] procedure Res_2K_Accepted;
    [Test] procedure Res_4K_Accepted;
    [Test] procedure Res_Empty_DefaultsTo2K;
    [Test] procedure Res_Lowercase2k_Accepted;
    [Test] procedure Res_Garbage_Rejected;
  end;

implementation

uses
  System.SysUtils,
  IUS.Upscaler.Intf,
  IUS.Validation;

procedure TValidationTests.Size_Below10MB_Accepted;
begin Assert.IsTrue(IsSizeAccepted(1)); end;

procedure TValidationTests.Size_Exactly10MB_Accepted;
begin Assert.IsTrue(IsSizeAccepted(10 * 1024 * 1024)); end;

procedure TValidationTests.Size_Above10MB_Rejected;
begin Assert.IsFalse(IsSizeAccepted(10 * 1024 * 1024 + 1)); end;

procedure TValidationTests.Mime_Jpeg_Accepted;
begin Assert.IsTrue(IsMimeAccepted('image/jpeg')); end;

procedure TValidationTests.Mime_Png_Accepted;
begin Assert.IsTrue(IsMimeAccepted('image/png')); end;

procedure TValidationTests.Mime_Webp_Accepted;
begin Assert.IsTrue(IsMimeAccepted('image/webp')); end;

procedure TValidationTests.Mime_Gif_Rejected;
begin Assert.IsFalse(IsMimeAccepted('image/gif')); end;

procedure TValidationTests.Mime_Empty_Rejected;
begin Assert.IsFalse(IsMimeAccepted('')); end;

function PngBytes: TBytes;
begin Result := TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0, 0, 0, 0); end;

function JpegBytes: TBytes;
begin Result := TBytes.Create($FF, $D8, $FF, $E0, 0, 0, 0, 0); end;

function WebpBytes: TBytes;
begin
  Result := TBytes.Create(
    $52, $49, $46, $46, $00, $00, $00, $00,
    $57, $45, $42, $50);
end;

procedure TValidationTests.Sniff_PngHeader_MatchesPngMime;
begin Assert.IsTrue(MagicBytesMatchMime(PngBytes, 'image/png')); end;

procedure TValidationTests.Sniff_JpegHeader_MatchesJpegMime;
begin Assert.IsTrue(MagicBytesMatchMime(JpegBytes, 'image/jpeg')); end;

procedure TValidationTests.Sniff_WebpHeader_MatchesWebpMime;
begin Assert.IsTrue(MagicBytesMatchMime(WebpBytes, 'image/webp')); end;

procedure TValidationTests.Sniff_PngHeader_DoesNotMatchJpegMime;
begin Assert.IsFalse(MagicBytesMatchMime(PngBytes, 'image/jpeg')); end;

procedure TValidationTests.Res_1K_Accepted;
var R: TUpscaleResolution;
begin
  Assert.IsTrue(TryParseResolution('1K', R));
  Assert.AreEqual(Ord(TUpscaleResolution.Res1K), Ord(R));
end;

procedure TValidationTests.Res_2K_Accepted;
var R: TUpscaleResolution;
begin
  Assert.IsTrue(TryParseResolution('2K', R));
  Assert.AreEqual(Ord(TUpscaleResolution.Res2K), Ord(R));
end;

procedure TValidationTests.Res_4K_Accepted;
var R: TUpscaleResolution;
begin
  Assert.IsTrue(TryParseResolution('4K', R));
  Assert.AreEqual(Ord(TUpscaleResolution.Res4K), Ord(R));
end;

procedure TValidationTests.Res_Empty_DefaultsTo2K;
var R: TUpscaleResolution;
begin
  Assert.IsTrue(TryParseResolution('', R));
  Assert.AreEqual(Ord(TUpscaleResolution.Res2K), Ord(R));
end;

procedure TValidationTests.Res_Lowercase2k_Accepted;
var R: TUpscaleResolution;
begin
  Assert.IsTrue(TryParseResolution('2k', R));
  Assert.AreEqual(Ord(TUpscaleResolution.Res2K), Ord(R));
end;

procedure TValidationTests.Res_Garbage_Rejected;
var R: TUpscaleResolution;
begin
  Assert.IsFalse(TryParseResolution('8K', R));
end;

initialization
  TDUnitX.RegisterTestFixture(TValidationTests);

end.
