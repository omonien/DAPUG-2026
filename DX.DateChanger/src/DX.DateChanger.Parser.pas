{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Strict YYYY-MM-DD filename-prefix parser with calendar validation.
  /// </summary>
  /// <remarks>
  ///   Pure functional unit. No I/O, no platform code. The basename is
  ///   considered to match if and only if its first 10 characters form a
  ///   valid Gregorian date in the YYYY-MM-DD format. Character at index 11
  ///   (if present) is unrestricted.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Parser;

interface

uses
  System.SysUtils;

type
  TParseResult = record
    Matched: Boolean;
    Date: TDate;
  end;

/// <summary>
///   Tries to parse a YYYY-MM-DD prefix from the basename of AFileName.
/// </summary>
/// <param name="AFileName">
///   File name or full path. Only the basename is inspected.
/// </param>
/// <returns>
///   Matched=True with Date populated when the basename starts with a valid
///   YYYY-MM-DD; otherwise Matched=False and Date is undefined.
/// </returns>
function TryParseFilenameDate(const AFileName: string): TParseResult;

implementation

uses
  System.IOUtils;

function IsAllDigits(const AValue: string): Boolean;
var
  LIndex: Integer;
begin
  if AValue = '' then
    Exit(False);
  for LIndex := 1 to Length(AValue) do
    if not CharInSet(AValue[LIndex], ['0'..'9']) then
      Exit(False);
  Result := True;
end;

function TryParseFilenameDate(const AFileName: string): TParseResult;
var
  LBase: string;
  LYearStr, LMonthStr, LDayStr: string;
  LYear, LMonth, LDay: Integer;
  LDate: TDateTime;
begin
  Result.Matched := False;
  Result.Date := 0;

  LBase := TPath.GetFileName(AFileName);
  if Length(LBase) < 10 then
    Exit;
  if (LBase[5] <> '-') or (LBase[8] <> '-') then
    Exit;

  LYearStr  := Copy(LBase, 1, 4);
  LMonthStr := Copy(LBase, 6, 2);
  LDayStr   := Copy(LBase, 9, 2);

  if not IsAllDigits(LYearStr) then Exit;
  if not IsAllDigits(LMonthStr) then Exit;
  if not IsAllDigits(LDayStr) then Exit;

  LYear  := StrToInt(LYearStr);
  LMonth := StrToInt(LMonthStr);
  LDay   := StrToInt(LDayStr);

  if LYear < 1 then Exit;

  if not TryEncodeDate(LYear, LMonth, LDay, LDate) then
    Exit;

  Result.Matched := True;
  Result.Date := LDate;
end;

end.