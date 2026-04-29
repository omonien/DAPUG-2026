unit IUS.Tests.DescribePrompt;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TDescribePromptTests = class
  public
    [Test]
    procedure Prompt_MatchesCanonicalText_ByteExact;
    [Test]
    procedure Prompt_LengthIsNonZero;
  end;

implementation

uses
  System.SysUtils,
  IUS.DescribePrompt;

const
  cExpectedPrompt =
    'You are looking at a single photographic image. Produce a JSON ' +
    'object with two fields:' + sLineBreak +
    '  title:   A 2-5 word noun phrase naming the dominant subject ' +
    'or scene.' + sLineBreak +
    '  caption: One or two sentences describing what is visible - ' +
    'subject, setting, mood, notable details. Plain prose, no lists, ' +
    'no markdown. Do not speculate beyond what is depicted.';

procedure TDescribePromptTests.Prompt_MatchesCanonicalText_ByteExact;
begin
  Assert.AreEqual(cExpectedPrompt, IUS.DescribePrompt.cDescribePrompt,
    'Describe prompt has drifted from the canonical text. ' +
    'If the change is intentional, update both the unit and this test.');
end;

procedure TDescribePromptTests.Prompt_LengthIsNonZero;
begin
  Assert.IsTrue(Length(IUS.DescribePrompt.cDescribePrompt) > 0, 'Prompt is empty');
end;

initialization
  TDUnitX.RegisterTestFixture(TDescribePromptTests);

end.
