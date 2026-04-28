{ -----------------------------------------------------------------------------
  /// <summary>
  ///   DUnitX tests for DX.DateChanger.Parser.
  /// </summary>
  /// <remarks>
  ///   Pure unit tests, no I/O. Covers strict YYYY-MM-DD prefix matching
  ///   plus calendar validation (leap years, month/day ranges).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Parser.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TParserTests = class
  public
    [Test]
    [TestCase('Plain extension',           '2026-04-28.jpg,2026-04-28')]
    [TestCase('Space and suffix',          '2026-04-28 photo.jpg,2026-04-28')]
    [TestCase('Underscore suffix',         '2026-04-28_note.txt,2026-04-28')]
    [TestCase('Letters at position 11',    '2026-04-28abc.txt,2026-04-28')]
    [TestCase('Exact 10 chars no suffix',  '2026-04-28,2026-04-28')]
    [TestCase('Leap year valid',           '2024-02-29.txt,2024-02-29')]
    procedure TryParse_ValidDates_ReturnsMatch(const AFileName, AExpectedIso: string);

    [Test]
    [TestCase('Invalid month 13',          '2026-13-01.txt')]
    [TestCase('Invalid month 00',          '2026-00-15.txt')]
    [TestCase('Invalid day Feb 30',        '2026-02-30.txt')]
    [TestCase('Invalid day Apr 31',        '2026-04-31.txt')]
    [TestCase('Non-leap Feb 29',           '2026-02-29.txt')]
    [TestCase('Year 0000',                 '0000-04-28.txt')]
    [TestCase('Day 00',                    '2026-04-00.txt')]
    procedure TryParse_InvalidDates_ReturnsNoMatch(const AFileName: string);

    [Test]
    [TestCase('Date in middle',            'notes-2026-04-28.txt')]
    [TestCase('2-digit year',              '26-04-28.txt')]
    [TestCase('Slash separators',          '2026/04/28.txt')]
    [TestCase('Dot separators',            '2026.04.28.txt')]
    [TestCase('Empty string',              '')]
    [TestCase('Too short',                 '2026-04')]
    [TestCase('Letters in date',           '2O26-04-28.txt')]
    procedure TryParse_NonMatchingShape_ReturnsNoMatch(const AFileName: string);

    [Test]
    procedure TryParse_FullPath_UsesBasename;
  end;

implementation

uses
  System.SysUtils, System.DateUtils,
  DX.DateChanger.Parser;

procedure TParserTests.TryParse_ValidDates_ReturnsMatch(const AFileName, AExpectedIso: string);
var
  LResult: TParseResult;
  LExpected: TDateTime;
begin
  LResult := TryParseFilenameDate(AFileName);
  Assert.IsTrue(LResult.Matched, 'Expected match for ' + AFileName);
  LExpected := EncodeDate(
    StrToInt(Copy(AExpectedIso, 1, 4)),
    StrToInt(Copy(AExpectedIso, 6, 2)),
    StrToInt(Copy(AExpectedIso, 9, 2)));
  Assert.AreEqual(LExpected, LResult.Date, 'Date mismatch for ' + AFileName);
end;

procedure TParserTests.TryParse_InvalidDates_ReturnsNoMatch(const AFileName: string);
var
  LResult: TParseResult;
begin
  LResult := TryParseFilenameDate(AFileName);
  Assert.IsFalse(LResult.Matched, 'Expected no match for ' + AFileName);
end;

procedure TParserTests.TryParse_NonMatchingShape_ReturnsNoMatch(const AFileName: string);
var
  LResult: TParseResult;
begin
  LResult := TryParseFilenameDate(AFileName);
  Assert.IsFalse(LResult.Matched, 'Expected no match for ' + AFileName);
end;

procedure TParserTests.TryParse_FullPath_UsesBasename;
var
  LResult: TParseResult;
begin
  LResult := TryParseFilenameDate('C:\Users\test\Documents\2026-04-28 photo.jpg');
  Assert.IsTrue(LResult.Matched);
  Assert.AreEqual(EncodeDate(2026, 4, 28), LResult.Date);
end;

initialization
  TDUnitX.RegisterTestFixture(TParserTests);

end.