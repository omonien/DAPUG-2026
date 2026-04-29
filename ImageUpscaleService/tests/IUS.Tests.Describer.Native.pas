unit IUS.Tests.Describer.Native;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNativeDescriberTests = class
  public
    [Test] procedure BuildRequestBody_ContainsPromptText;
    [Test] procedure BuildRequestBody_ContainsInlineDataWithMime;
    [Test] procedure BuildRequestBody_ContainsResponseSchema;
    [Test] procedure BuildRequestBody_Base64IsUnbroken;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  System.JSON,
  IUS.Describer.Native,
  IUS.DescribePrompt;

function MakeDescriber: TNativeDescriber;
begin
  Result := TNativeDescriber.Create('AIza-test-key', 'gemini-3.1-flash-lite-preview');
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsPromptText;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, 'You are looking at a single photographic image');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsInlineDataWithMime;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, '"inlineData"');
    Assert.Contains(LBody, '"mimeType":"image\/png"');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsResponseSchema;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, '"responseMimeType":"application\/json"');
    Assert.Contains(LBody, '"responseSchema"');
    Assert.Contains(LBody, '"title"');
    Assert.Contains(LBody, '"caption"');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_Base64IsUnbroken;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  // Use 100 bytes - long enough that wrap-style base64 would insert a newline.
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(
      TEncoding.ASCII.GetBytes(StringOfChar('X', 100)), 'image/png');
    Assert.IsFalse(LBody.Contains(#13), 'Body must not contain CR');
    Assert.IsFalse(LBody.Contains(#10), 'Body must not contain LF');
  finally
    LDescriber.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNativeDescriberTests);

end.
