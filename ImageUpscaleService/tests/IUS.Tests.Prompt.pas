unit IUS.Tests.Prompt;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPromptTests = class
  public
    [Test]
    procedure Prompt_MatchesCanonicalText_ByteExact;
    [Test]
    procedure Prompt_LengthIsNonZero;
  end;

implementation

uses
  System.SysUtils,
  IUS.Prompt;

const
  cExpectedPrompt =
    'Take the provided image and remaster it to pristine ultra-high-definition cinematic quality. ' +
    'Every aspect of the original must remain completely intact - the person''s facial identity, ' +
    'expression, body posture, clothing, accessories, environment, framing and overall composition ' +
    'stay exactly as they are. No elements are changed, added or removed.' + sLineBreak +
    'The upgrade is purely technical.' + sLineBreak +
    'Reconstruct skin texture with natural visible pores and subtle real-world detail. ' +
    'Define individual hair strands with precision.' + sLineBreak +
    'Render the eyes sharp, clear and fully alive.' + sLineBreak +
    'Clean and resolve every edge throughout the entire image.' + sLineBreak +
    'Enhance the dynamic range, contrast and three-dimensional depth using balanced studio-grade ' +
    'cinematic lighting that makes every surface feel physically present and real.';

procedure TPromptTests.Prompt_MatchesCanonicalText_ByteExact;
begin
  Assert.AreEqual(cExpectedPrompt, IUS.Prompt.cRemasterPrompt,
    'Remaster prompt has drifted from the canonical text. ' +
    'If the change is intentional, update both the unit and this test.');
end;

procedure TPromptTests.Prompt_LengthIsNonZero;
begin
  Assert.IsTrue(Length(IUS.Prompt.cRemasterPrompt) > 0, 'Prompt is empty');
end;

initialization
  TDUnitX.RegisterTestFixture(TPromptTests);

end.
