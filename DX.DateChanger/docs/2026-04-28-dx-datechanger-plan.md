# DX.DateChanger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `DX.DateChanger`, a cross-platform (Windows + macOS) FireMonkey utility that sets file creation/modification/access timestamps to the date encoded in a filename prefix (`YYYY-MM-DD`) at 10:00 local time.

**Architecture:** Three-layer Delphi project. Pure parser unit (no I/O), file-time setter behind an `IFileTimeSetter` interface with one Windows and one macOS implementation, and an orchestrator service that ties them together. The FMX form is a thin shell that wires drop events to the service. DUnitX as a Git submodule for tests; mock `IFileTimeSetter` makes the service unit-testable without touching the file system.

**Tech Stack:** Delphi 12 Athens · FireMonkey (FMX) · Win32/Win64/OSXARM64 targets · DUnitX (submodule) · MIT licensed.

**Reference:** This plan implements the design in [`DX.DateChanger/docs/2026-04-28-dx-datechanger-prd.md`](2026-04-28-dx-datechanger-prd.md). Read it first if anything below is unclear.

---

## Working directory

All commands assume the current directory is the **repo root** (`DAPUG-2026/`). Project files live under `DX.DateChanger/`.

```
DX.DateChanger/
├── DX.DateChanger.dproj         (Task 7)
├── DX.DateChanger.dpr           (Task 7)
├── src/
│   ├── DX.DateChanger.Parser.pas       (Task 3)
│   ├── DX.DateChanger.FileTime.pas     (Task 4 stub, Task 5 Win impl, Task 6 Mac impl)
│   ├── DX.DateChanger.Service.pas      (Task 4)
│   ├── FormMain.pas                    (Task 7)
│   └── FormMain.fmx                    (Task 7)
├── tests/
│   ├── DX.DateChangerTests.dproj           (Task 2)
│   ├── DX.DateChangerTests.dpr             (Task 2; updated each task)
│   ├── DX.DateChanger.Parser.Tests.pas     (Task 3)
│   ├── DX.DateChanger.Service.Tests.pas    (Task 4)
│   └── DX.DateChanger.FileTime.Tests.pas   (Task 5)
├── libs/
│   └── DUnitX/                  (Task 1, git submodule)
├── build/                       (gitignored output dir)
└── docs/
    ├── 2026-04-28-dx-datechanger-prd.md     (already exists)
    └── 2026-04-28-dx-datechanger-plan.md    (this file)
```

---

## Coding conventions (apply to every task)

Per `Delphi.md` in the user's global rules:

- **Encoding:** `.pas` saved as **UTF-8 with BOM**, `.fmx` saved as text format with `#<codepoint>` for non-ASCII, **CRLF** line endings everywhere. Already enforced by repo `.gitattributes`.
- **Naming:** PascalCase. Classes `T`, interfaces `I`, exceptions `E`. Locals `L`, fields `F`, parameters `A`. Constants `c` / `sc` (string) / `rs` (resource string).
- **Scoped enums:** `{$SCOPEDENUMS ON}` at the top of any unit defining enums.
- **Unit header:** Every `.pas` starts with the XML-doc header (template below). Copyright `Olaf Monien`, year `2026`, MIT.
- **No trivial comments.** XML doc on classes and public methods only. Explain *what* and *why*; never narrate trivia.

### Standard unit header (paste verbatim, fill in summary/remarks)

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   <FILL IN one-line summary>
  /// </summary>
  /// <remarks>
  ///   <FILL IN: relevant details, design decisions, references, edge cases>
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
```

---

## Task 1: Add DUnitX submodule, build script, and .gitignore

**Files:**
- Create: `DX.DateChanger/.gitignore`
- Create: `DX.DateChanger/libs/DUnitX/` (via git submodule)
- Copy:   `DX.DateChanger/build/DelphiBuildDPROJ.ps1` (universal Delphi build script from `omonien/DelphiStandards`; copy from `C:\Projekte\DX.Editor\build\DelphiBuildDPROJ.ps1` or any other project that already has it)
- Create: `DX.DateChanger/build/.gitkeep` (so the otherwise empty/gitignored dir keeps the build script tracked)

- [ ] **Step 1: Add DUnitX as a git submodule**

Run:

```bash
git submodule add https://github.com/VSoftTechnologies/DUnitX.git DX.DateChanger/libs/DUnitX
```

Expected: `Cloning into 'DX.DateChanger/libs/DUnitX'...` and a new `.gitmodules` file created at the repo root.

- [ ] **Step 2: Copy the universal build script**

```bash
mkdir -p DX.DateChanger/build
cp /c/Projekte/DX.Editor/build/DelphiBuildDPROJ.ps1 DX.DateChanger/build/DelphiBuildDPROJ.ps1
```

- [ ] **Step 3: Create the project-local .gitignore**

Create `DX.DateChanger/.gitignore` with this content:

```gitignore
# Build output (binaries + DCUs land here; keep the dir, drop the contents)
build/Win32/
build/Win64/
build/OSX64/
build/OSXARM64/

# Delphi local artefacts
*.identcache
*.local
*.dsk
*.tvsconfig
__history/
__recovery/
*.~*
```

- [ ] **Step 4: Verify**

```bash
git status
```

Expected: shows `.gitmodules`, `DX.DateChanger/.gitignore`, `DX.DateChanger/build/DelphiBuildDPROJ.ps1`, and the new submodule entry as untracked/staged.

- [ ] **Step 5: Commit**

```bash
git add .gitmodules DX.DateChanger/.gitignore DX.DateChanger/build/DelphiBuildDPROJ.ps1 DX.DateChanger/libs/DUnitX
git commit -m "chore(dx.datechanger): add DUnitX submodule, build script, and gitignore

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Empty DUnitX test project that compiles and runs

**Goal:** Get a runnable `DX.DateChangerTests.exe` that reports "0 tests" so the test harness is verified end-to-end before any real test exists.

**Files:**
- Create: `DX.DateChanger/tests/DX.DateChangerTests.dproj`
- Create: `DX.DateChanger/tests/DX.DateChangerTests.dpr`

- [ ] **Step 1: Create the test project via Delphi IDE**

Open Delphi 12 Athens.

- `File > New > Other... > Delphi Projects > DUnitX > DUnitX Test Project`
- Untick "Create unit tests for an existing unit" (we will add tests as separate units).
- Project name: `DX.DateChangerTests`
- Save location: `DX.DateChanger/tests/`

The IDE generates `DX.DateChangerTests.dproj` and `DX.DateChangerTests.dpr`.

In **Project > Options**:
- **Building > Delphi Compiler > Output directory**: `..\build\$(Platform)\$(Config)`
- **Building > Delphi Compiler > Unit output directory**: `..\build\$(Platform)\$(Config)\dcu`
- **Building > Delphi Compiler > Search path**: add `..\src;..\libs\DUnitX\Source`
- **Description > Application > Target platforms**: enable **Win64** (and **OSXARM64** if developing on macOS).

Save and close project options.

- [ ] **Step 2: Replace the generated `.dpr` content**

Open `DX.DateChanger/tests/DX.DateChangerTests.dpr` and replace its content with:

```pascal
program DX.DateChangerTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  {$ENDIF }
  DUnitX.Exceptions,
  DUnitX.TestFramework;

{$IFNDEF TESTINSIGHT}
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
{$ENDIF}
begin
  ReportMemoryLeaksOnShutdown := True;
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;
    {$IFNDEF CI}
    System.Write('Done.. press <Enter> key to quit.');
    System.Readln;
    {$ENDIF}
  except
    // Transient: DUnitX raises ENoTestsRegistered when no fixtures exist
    // (verified in DUnitX.TestRunner.pas). Once fixtures are registered
    // in Task 3 this branch becomes unreachable and should be removed.
    on E: ENoTestsRegistered do
    begin
      System.Writeln('Tests Found        : 0');
      System.Writeln('Tests Passed       : 0');
      System.ExitCode := EXIT_OK;
    end;
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.
```

Save with **UTF-8 with BOM** encoding (Delphi IDE: `File > Save As > Encoding`).

- [ ] **Step 3: Build and run from the IDE**

Press `Shift+F9` (compile) then `Ctrl+F9` (build).

Expected: build succeeds with 0 errors. Output binary at `DX.DateChanger/build/Win64/Debug/DX.DateChangerTests.exe`.

Run with `Ctrl+F9` then `F9`. Console output should include:

```
Tests Found        : 0
Tests Ignored      : 0
Tests Passed       : 0
Tests Leaked       : 0
Tests Failed       : 0
Tests Errored      : 0
Done.. press <Enter> key to quit.
```

- [ ] **Step 4: Run from CLI to verify the build script works**

`DelphiBuildDPROJ.ps1` was already copied into `DX.DateChanger/build/` in Task 1. Use it (auto-detects latest Delphi from the registry, sources `rsvars.bat`, finds `msbuild`):

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 `
    -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj `
    -Platform Win64 -Config Debug
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected: same "0 tests" output as Step 3 (the `--exitbehavior:Continue` arg suppresses the Enter prompt).

- [ ] **Step 5: Commit**

```bash
git add DX.DateChanger/tests/DX.DateChangerTests.dproj \
        DX.DateChanger/tests/DX.DateChangerTests.dpr
git commit -m "chore(dx.datechanger): add DUnitX test project skeleton

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Parser unit — TDD

**Files:**
- Create: `DX.DateChanger/tests/DX.DateChanger.Parser.Tests.pas`
- Modify: `DX.DateChanger/tests/DX.DateChangerTests.dpr` (add to `uses`; remove transient `ENoTestsRegistered` catch)
- Create: `DX.DateChanger/src/DX.DateChanger.Parser.pas`

- [ ] **Step 0: Remove the Task 2 transient `ENoTestsRegistered` catch from `DX.DateChangerTests.dpr`**

The catch was added in Task 2 to print "0 tests" cleanly when no fixtures existed. Now that real fixtures will be registered, the catch becomes dead code. Reduce the `except` block back to:

```pascal
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
```

Also remove the now-unused `DUnitX.Exceptions` from the `uses` clause.

- [ ] **Step 1: Write the failing test unit**

Create `DX.DateChanger/tests/DX.DateChanger.Parser.Tests.pas`:

```pascal
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
```

- [ ] **Step 2: Add the unit to the test project**

In `DX.DateChanger/tests/DX.DateChangerTests.dpr`, add to the `uses` clause (after `DUnitX.TestFramework`):

```pascal
  DUnitX.TestFramework,
  DX.DateChanger.Parser in '..\src\DX.DateChanger.Parser.pas',
  DX.DateChanger.Parser.Tests in 'DX.DateChanger.Parser.Tests.pas';
```

In Delphi IDE: also right-click the project in Project Manager → `Add...` and add both files so they appear in the `.dproj`.

- [ ] **Step 3: Verify the test project fails to compile (parser unit doesn't exist yet)**

Run:

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
```

Expected: build **fails** with `[dcc32 Fatal Error] DX.DateChangerTests.dpr(...): F1026 File not found: 'DX.DateChanger.Parser.dcu'` or similar.

This confirms the test references the not-yet-created unit.

- [ ] **Step 4: Implement the parser unit**

Create `DX.DateChanger/src/DX.DateChanger.Parser.pas`:

```pascal
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
```

Save with **UTF-8 BOM**.

- [ ] **Step 5: Add the unit to the test project's source path**

The path is already configured (`..\src` was added to Search path in Task 2). No further change needed.

- [ ] **Step 6: Build and run tests**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected output (counts will match the test cases above):

```
Tests Found        : 22
Tests Passed       : 22
Tests Failed       : 0
Tests Errored      : 0
```

If any test fails: read the failure message, fix the parser, re-run. Do not commit until green.

- [ ] **Step 7: Commit**

```bash
git add DX.DateChanger/src/DX.DateChanger.Parser.pas \
        DX.DateChanger/tests/DX.DateChanger.Parser.Tests.pas \
        DX.DateChanger/tests/DX.DateChangerTests.dproj \
        DX.DateChanger/tests/DX.DateChangerTests.dpr
git commit -m "feat(dx.datechanger): add filename date parser with tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Service unit — TDD with mock IFileTimeSetter

**Files:**
- Create: `DX.DateChanger/src/DX.DateChanger.FileTime.pas` (interface + EFileTimeError + factory placeholder)
- Create: `DX.DateChanger/tests/DX.DateChanger.Service.Tests.pas`
- Modify: `DX.DateChanger/tests/DX.DateChangerTests.dpr` (add new units)
- Create: `DX.DateChanger/src/DX.DateChanger.Service.pas`

- [ ] **Step 1: Define the FileTime interface and exception (no impl yet)**

Create `DX.DateChanger/src/DX.DateChanger.FileTime.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IFileTimeSetter abstraction for setting creation, modification and
  ///   access timestamps on a file in a platform-independent way.
  /// </summary>
  /// <remarks>
  ///   The interface decouples the orchestrator (TDateChangerService) from
  ///   OS-specific file APIs and makes the orchestrator unit-testable with
  ///   a mock. Concrete implementations are added in a later task: Win32
  ///   uses SetFileTime; macOS uses NSFileManager + utimes.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.FileTime;

interface

uses
  System.SysUtils;

type
  EFileTimeError = class(Exception)
  public
    OSErrorCode: Integer;
    constructor Create(const AMessage: string; AOSErrorCode: Integer);
  end;

  IFileTimeSetter = interface
    ['{B9D8C5E1-3A2F-4F77-9F1B-7A2A2C3E5D11}']
    /// <summary>
    ///   Sets creation, modification and access timestamps of APath to AWhen.
    ///   Raises EFileTimeError on failure with OSErrorCode populated.
    /// </summary>
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

/// <summary>
///   Returns the platform-default IFileTimeSetter implementation. Raises
///   ENotImplemented on platforms with no implementation yet.
/// </summary>
function CreateFileTimeSetter: IFileTimeSetter;

implementation

constructor EFileTimeError.Create(const AMessage: string; AOSErrorCode: Integer);
begin
  inherited Create(AMessage);
  Self.OSErrorCode := AOSErrorCode;
end;

function CreateFileTimeSetter: IFileTimeSetter;
begin
  raise ENotImplemented.Create('CreateFileTimeSetter: no implementation yet');
end;

end.
```

The `CreateFileTimeSetter` factory raises `ENotImplemented` for now. Tasks 5 and 6 fill in real Windows / macOS implementations.

- [ ] **Step 2: Write the failing service test unit**

Create `DX.DateChanger/tests/DX.DateChanger.Service.Tests.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   DUnitX tests for DX.DateChanger.Service using a mock IFileTimeSetter.
  /// </summary>
  /// <remarks>
  ///   Tests the orchestration logic without touching the file system: a
  ///   mock IFileTimeSetter records calls and can be configured to throw.
  ///   Each test creates real temp files only when it needs the orchestrator
  ///   to walk a directory or detect file vs. directory.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Service.Tests;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  DUnitX.TestFramework,
  DX.DateChanger.FileTime,
  DX.DateChanger.Service;

type
  TMockCall = record
    Path: string;
    Time: TDateTime;
  end;

  TMockFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  private
    FCalls: TList<TMockCall>;
    FFailWithCode: Integer;
    FFailForPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
    /// Configure: when SetTimes is called for AFailForPath, raise
    /// EFileTimeError with AOSErrorCode. Pass empty path to fail every call.
    procedure FailWith(const AFailForPath: string; AOSErrorCode: Integer);
    property Calls: TList<TMockCall> read FCalls;
  end;

  [TestFixture]
  TServiceTests = class
  private
    FMock: TMockFileTimeSetter;
    FMockIntf: IFileTimeSetter;
    FService: TDateChangerService;
    FTempDir: string;
    function MakeTempFile(const AName: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure ProcessDrop_EmptyArray_AllZero;
    [Test] procedure ProcessDrop_OneMatchingFile_ProcessedOne;
    [Test] procedure ProcessDrop_OneNonMatchingFile_SkippedOne;
    [Test] procedure ProcessDrop_MixedBatch_CountersCorrect;
    [Test] procedure ProcessDrop_MatchingFile_TimeIsTenAm;
    [Test] procedure ProcessDrop_FolderTopLevelOnly_SubdirsIgnored;
    [Test] procedure ProcessDrop_AccessDenied_CountedAsSkipped;
    [Test] procedure ProcessDrop_OtherError_CountedAsError;
    [Test] procedure ProcessDrop_NonExistentPath_CountedAsError;
    [Test] procedure ProcessDrop_ErrorsTriggerLogPath;
  end;

implementation

uses
  System.DateUtils;

const
{$IFDEF MSWINDOWS}
  cAccessDeniedCode = 5; // ERROR_ACCESS_DENIED
{$ELSE}
  cAccessDeniedCode = 13; // EACCES
{$ENDIF}

{ TMockFileTimeSetter }

constructor TMockFileTimeSetter.Create;
begin
  inherited Create;
  FCalls := TList<TMockCall>.Create;
  FFailWithCode := 0;
end;

destructor TMockFileTimeSetter.Destroy;
begin
  FCalls.Free;
  inherited;
end;

procedure TMockFileTimeSetter.FailWith(const AFailForPath: string; AOSErrorCode: Integer);
begin
  FFailForPath := AFailForPath;
  FFailWithCode := AOSErrorCode;
end;

procedure TMockFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LCall: TMockCall;
begin
  LCall.Path := APath;
  LCall.Time := AWhen;
  FCalls.Add(LCall);
  if (FFailWithCode <> 0) and ((FFailForPath = '') or (FFailForPath = APath)) then
    raise EFileTimeError.Create('mock failure', FFailWithCode);
end;

{ TServiceTests }

function TServiceTests.MakeTempFile(const AName: string): string;
begin
  Result := TPath.Combine(FTempDir, AName);
  TFile.WriteAllText(Result, 'x');
end;

procedure TServiceTests.Setup;
begin
  FMock := TMockFileTimeSetter.Create;
  FMockIntf := FMock;
  FService := TDateChangerService.Create(FMockIntf);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'dxdc_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TServiceTests.TearDown;
begin
  FreeAndNil(FService);
  FMockIntf := nil;
  FMock := nil;
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TServiceTests.ProcessDrop_EmptyArray_AllZero;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_OneMatchingFile_ProcessedOne;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28 photo.jpg');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(1, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
  Assert.AreEqual(1, FMock.Calls.Count);
  Assert.AreEqual(LPath, FMock.Calls[0].Path);
end;

procedure TServiceTests.ProcessDrop_OneNonMatchingFile_SkippedOne;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('notes.txt');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
  Assert.AreEqual(0, FMock.Calls.Count);
end;

procedure TServiceTests.ProcessDrop_MixedBatch_CountersCorrect;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([
    MakeTempFile('2026-04-28a.txt'),
    MakeTempFile('2026-04-29b.txt'),
    MakeTempFile('readme.md'),
    MakeTempFile('2026-13-01.txt') // invalid date, counts as skipped
  ]);
  Assert.AreEqual(2, LResult.Processed);
  Assert.AreEqual(2, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_MatchingFile_TimeIsTenAm;
var
  LPath: string;
  LResult: TDropResult;
  LExpected: TDateTime;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(1, LResult.Processed);
  LExpected := EncodeDateTime(2026, 4, 28, 10, 0, 0, 0);
  Assert.AreEqual(LExpected, FMock.Calls[0].Time);
end;

procedure TServiceTests.ProcessDrop_FolderTopLevelOnly_SubdirsIgnored;
var
  LSub: string;
  LResult: TDropResult;
begin
  MakeTempFile('2026-04-28a.txt'); // top level: matches
  MakeTempFile('readme.md');       // top level: skipped
  LSub := TPath.Combine(FTempDir, 'sub');
  TDirectory.CreateDirectory(LSub);
  TFile.WriteAllText(TPath.Combine(LSub, '2026-04-28b.txt'), 'x'); // ignored

  LResult := FService.ProcessDrop([FTempDir]);
  Assert.AreEqual(1, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_AccessDenied_CountedAsSkipped;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', cAccessDeniedCode);
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(1, LResult.Skipped);
  Assert.AreEqual(0, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_OtherError_CountedAsError;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', 999);
  LResult := FService.ProcessDrop([LPath]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(1, LResult.Errors);
  Assert.IsTrue(LResult.LogPath <> '', 'LogPath should be populated when errors > 0');
end;

procedure TServiceTests.ProcessDrop_NonExistentPath_CountedAsError;
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop([TPath.Combine(FTempDir, 'does-not-exist.txt')]);
  Assert.AreEqual(0, LResult.Processed);
  Assert.AreEqual(0, LResult.Skipped);
  Assert.AreEqual(1, LResult.Errors);
end;

procedure TServiceTests.ProcessDrop_ErrorsTriggerLogPath;
var
  LPath: string;
  LResult: TDropResult;
begin
  LPath := MakeTempFile('2026-04-28.txt');
  FMock.FailWith('', 999);
  LResult := FService.ProcessDrop([LPath]);
  Assert.IsTrue(TFile.Exists(LResult.LogPath), 'Error log file should be created');
end;

initialization
  TDUnitX.RegisterTestFixture(TServiceTests);

end.
```

- [ ] **Step 3: Add new units to the test project**

In `DX.DateChanger/tests/DX.DateChangerTests.dpr`, extend the `uses` clause:

```pascal
  DUnitX.TestFramework,
  DX.DateChanger.Parser in '..\src\DX.DateChanger.Parser.pas',
  DX.DateChanger.FileTime in '..\src\DX.DateChanger.FileTime.pas',
  DX.DateChanger.Service in '..\src\DX.DateChanger.Service.pas',
  DX.DateChanger.Parser.Tests in 'DX.DateChanger.Parser.Tests.pas',
  DX.DateChanger.Service.Tests in 'DX.DateChanger.Service.Tests.pas';
```

In Delphi IDE: also add `DX.DateChanger.FileTime.pas`, `DX.DateChanger.Service.pas`, and `DX.DateChanger.Service.Tests.pas` via Project Manager → `Add...`.

- [ ] **Step 4: Verify build fails (Service unit not yet defined)**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
```

Expected: build fails with `F1026 File not found: 'DX.DateChanger.Service.dcu'` or similar.

- [ ] **Step 5: Implement the Service unit**

Create `DX.DateChanger/src/DX.DateChanger.Service.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Orchestrator that processes a dropped batch of paths: parses dates
  ///   from filenames and delegates timestamp writes to an IFileTimeSetter.
  /// </summary>
  /// <remarks>
  ///   - Walks dropped paths: directories are enumerated top-level only.
  ///   - Per-platform access-denied codes are detected (ERROR_ACCESS_DENIED
  ///     on Windows, EACCES on macOS) and counted as Skipped, not errors.
  ///   - Other failures are appended to a per-user error log.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.Service;

interface

uses
  System.SysUtils, System.Classes,
  DX.DateChanger.FileTime;

type
  TDropResult = record
    Processed: Integer;
    Skipped:   Integer;
    Errors:    Integer;
    LogPath:   string;
  end;

  TDateChangerService = class
  private
    FTimeSetter: IFileTimeSetter;
    FLogPath: string;
    function GetLogPath: string;
    procedure AppendErrorLog(const APath: string; AErrorCode: Integer; const AMessage: string);
    procedure ProcessOneFile(const APath: string; var AResult: TDropResult);
    function IsAccessDenied(AOSErrorCode: Integer): Boolean;
  public
    constructor Create(const ATimeSetter: IFileTimeSetter);
    function ProcessDrop(const APaths: TArray<string>): TDropResult;
  end;

implementation

uses
  System.DateUtils, System.IOUtils
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF}
  {$IFDEF POSIX}, Posix.Errno{$ENDIF};

const
{$IFDEF MSWINDOWS}
  cAccessDeniedCode = ERROR_ACCESS_DENIED;
{$ELSE}
  cAccessDeniedCode = EACCES;
{$ENDIF}

{ TDateChangerService }

constructor TDateChangerService.Create(const ATimeSetter: IFileTimeSetter);
begin
  inherited Create;
  FTimeSetter := ATimeSetter;
end;

function TDateChangerService.IsAccessDenied(AOSErrorCode: Integer): Boolean;
begin
  Result := AOSErrorCode = cAccessDeniedCode;
end;

function TDateChangerService.GetLogPath: string;
var
  LDir: string;
begin
  if FLogPath <> '' then
    Exit(FLogPath);
{$IFDEF MSWINDOWS}
  LDir := TPath.Combine(TPath.GetHomePath, 'DX.DateChanger');
{$ENDIF}
{$IFDEF MACOS}
  LDir := TPath.Combine(TPath.Combine(TPath.GetLibraryPath, 'Application Support'), 'DX.DateChanger');
{$ENDIF}
  TDirectory.CreateDirectory(LDir);
  FLogPath := TPath.Combine(LDir, 'errors.log');
  Result := FLogPath;
end;

procedure TDateChangerService.AppendErrorLog(const APath: string; AErrorCode: Integer; const AMessage: string);
var
  LStream: TStreamWriter;
  LLine: string;
begin
  LLine := Format('%s'#9'%s'#9'%d'#9'%s',
    [DateToISO8601(Now, False), APath, AErrorCode, AMessage]);
  LStream := TFile.AppendText(GetLogPath);
  try
    LStream.WriteLine(LLine);
  finally
    LStream.Free;
  end;
end;

procedure TDateChangerService.ProcessOneFile(const APath: string; var AResult: TDropResult);
var
  LParse: TParseResult;
  LWhen: TDateTime;
begin
  if not TFile.Exists(APath) then
  begin
    Inc(AResult.Errors);
    AppendErrorLog(APath, 0, 'File not found');
    Exit;
  end;

  LParse := DX.DateChanger.Parser.TryParseFilenameDate(APath);
  if not LParse.Matched then
  begin
    Inc(AResult.Skipped);
    Exit;
  end;

  LWhen := LParse.Date + EncodeTime(10, 0, 0, 0);
  try
    FTimeSetter.SetTimes(APath, LWhen);
    Inc(AResult.Processed);
  except
    on E: EFileTimeError do
    begin
      if IsAccessDenied(E.OSErrorCode) then
        Inc(AResult.Skipped)
      else
      begin
        Inc(AResult.Errors);
        AppendErrorLog(APath, E.OSErrorCode, E.Message);
      end;
    end;
  end;
end;

function TDateChangerService.ProcessDrop(const APaths: TArray<string>): TDropResult;
var
  LPath: string;
  LFile: string;
begin
  Result := Default(TDropResult);

  for LPath in APaths do
  begin
    if TDirectory.Exists(LPath) then
    begin
      for LFile in TDirectory.GetFiles(LPath) do
        ProcessOneFile(LFile, Result);
    end
    else
      ProcessOneFile(LPath, Result);
  end;

  if Result.Errors > 0 then
    Result.LogPath := GetLogPath;
end;

end.
```

Note: the `uses` clause needs `DX.DateChanger.Parser`. Add it:

```pascal
uses
  System.SysUtils, System.Classes,
  DX.DateChanger.FileTime,
  DX.DateChanger.Parser;
```

(Already present in the snippet above? Re-check and ensure `DX.DateChanger.Parser` is in the implementation `uses` of the Service unit's `interface` section is fine, since `TParseResult` is referenced only inside the implementation. Move it to implementation `uses` to keep the public interface narrow.)

Final `uses` layout:

- `interface` `uses`: `System.SysUtils, System.Classes, DX.DateChanger.FileTime`
- `implementation` `uses`: `System.DateUtils, System.IOUtils, DX.DateChanger.Parser, [Winapi.Windows or Posix.Errno]`

- [ ] **Step 6: Build and run tests**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected: all parser tests + all service tests pass (≈ 32 tests total). If any fail, fix the service logic before continuing.

- [ ] **Step 7: Commit**

```bash
git add DX.DateChanger/src/DX.DateChanger.FileTime.pas \
        DX.DateChanger/src/DX.DateChanger.Service.pas \
        DX.DateChanger/tests/DX.DateChanger.Service.Tests.pas \
        DX.DateChanger/tests/DX.DateChangerTests.dproj \
        DX.DateChanger/tests/DX.DateChangerTests.dpr
git commit -m "feat(dx.datechanger): add orchestrator service with mock-based tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Windows file-time implementation + smoke test

**Files:**
- Modify: `DX.DateChanger/src/DX.DateChanger.FileTime.pas` (add `TWinFileTimeSetter`, fill `CreateFileTimeSetter`)
- Create: `DX.DateChanger/tests/DX.DateChanger.FileTime.Tests.pas`
- Modify: `DX.DateChanger/tests/DX.DateChangerTests.dpr` (add new test unit)

- [ ] **Step 1: Write the smoke-test unit (will fail until impl exists)**

Create `DX.DateChanger/tests/DX.DateChanger.FileTime.Tests.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Smoke test for the platform IFileTimeSetter implementation. Creates
  ///   a temp file, calls SetTimes, reads timestamps back, asserts within
  ///   1-second tolerance.
  /// </summary>
  /// <remarks>
  ///   Cross-platform: runs on whichever OS the test suite is launched on.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit DX.DateChanger.FileTime.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFileTimeTests = class
  public
    [Test] procedure SetTimes_Roundtrip_TimestampsMatchWithinOneSecond;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils,
  DX.DateChanger.FileTime;

procedure TFileTimeTests.SetTimes_Roundtrip_TimestampsMatchWithinOneSecond;
var
  LSetter: IFileTimeSetter;
  LPath: string;
  LWhen: TDateTime;
begin
  LSetter := CreateFileTimeSetter;
  LPath := TPath.Combine(TPath.GetTempPath, 'dxdc_smoke_' + TGUID.NewGuid.ToString + '.txt');
  TFile.WriteAllText(LPath, 'x');
  try
    LWhen := EncodeDateTime(2026, 4, 28, 10, 0, 0, 0);
    LSetter.SetTimes(LPath, LWhen);
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetCreationTime(LPath))) <= 1,
      'Creation time mismatch');
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetLastWriteTime(LPath))) <= 1,
      'Modification time mismatch');
    Assert.IsTrue(Abs(SecondsBetween(LWhen, TFile.GetLastAccessTime(LPath))) <= 1,
      'Access time mismatch');
  finally
    TFile.Delete(LPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFileTimeTests);

end.
```

- [ ] **Step 2: Add the test unit to the test project**

Extend `uses` in `DX.DateChanger/tests/DX.DateChangerTests.dpr`:

```pascal
  DX.DateChanger.FileTime.Tests in 'DX.DateChanger.FileTime.Tests.pas';
```

Also add the file via Delphi IDE Project Manager → `Add...`.

- [ ] **Step 3: Run tests — expect smoke test to fail**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected: smoke test errors with `ENotImplemented: CreateFileTimeSetter: no implementation yet`.

- [ ] **Step 4: Implement `TWinFileTimeSetter`**

Replace the body of `DX.DateChanger/src/DX.DateChanger.FileTime.pas` with:

```pascal
unit DX.DateChanger.FileTime;

interface

uses
  System.SysUtils;

type
  EFileTimeError = class(Exception)
  public
    OSErrorCode: Integer;
    constructor Create(const AMessage: string; AOSErrorCode: Integer);
  end;

  IFileTimeSetter = interface
    ['{B9D8C5E1-3A2F-4F77-9F1B-7A2A2C3E5D11}']
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

function CreateFileTimeSetter: IFileTimeSetter;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.DateUtils;

constructor EFileTimeError.Create(const AMessage: string; AOSErrorCode: Integer);
begin
  inherited Create(AMessage);
  Self.OSErrorCode := AOSErrorCode;
end;

{$IFDEF MSWINDOWS}
type
  TWinFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  public
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

procedure TWinFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LHandle: THandle;
  LSysTime: TSystemTime;
  LFileTimeUtc: TFileTime;
  LWhenUtc: TDateTime;
  LErr: Integer;
begin
  LHandle := CreateFileW(PChar(APath), GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    LErr := GetLastError;
    raise EFileTimeError.Create('CreateFileW failed: ' + SysErrorMessage(LErr), LErr);
  end;
  try
    LWhenUtc := TTimeZone.Local.ToUniversalTime(AWhen);
    DateTimeToSystemTime(LWhenUtc, LSysTime);
    if not SystemTimeToFileTime(LSysTime, LFileTimeUtc) then
    begin
      LErr := GetLastError;
      raise EFileTimeError.Create('SystemTimeToFileTime failed', LErr);
    end;
    if not SetFileTime(LHandle, @LFileTimeUtc, @LFileTimeUtc, @LFileTimeUtc) then
    begin
      LErr := GetLastError;
      raise EFileTimeError.Create('SetFileTime failed: ' + SysErrorMessage(LErr), LErr);
    end;
  finally
    CloseHandle(LHandle);
  end;
end;
{$ENDIF}

function CreateFileTimeSetter: IFileTimeSetter;
begin
{$IFDEF MSWINDOWS}
  Result := TWinFileTimeSetter.Create;
{$ELSE}
  raise ENotImplemented.Create('CreateFileTimeSetter: macOS impl pending (Task 6)');
{$ENDIF}
end;

end.
```

- [ ] **Step 5: Build and run tests on Windows**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected: all tests pass, including `SetTimes_Roundtrip_TimestampsMatchWithinOneSecond`.

- [ ] **Step 6: Commit**

```bash
git add DX.DateChanger/src/DX.DateChanger.FileTime.pas \
        DX.DateChanger/tests/DX.DateChanger.FileTime.Tests.pas \
        DX.DateChanger/tests/DX.DateChangerTests.dproj \
        DX.DateChanger/tests/DX.DateChangerTests.dpr
git commit -m "feat(dx.datechanger): add Win32 IFileTimeSetter implementation with smoke test

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: macOS file-time implementation

**Prerequisite:** access to a Mac with Delphi or PAServer pointing at one. If you only have Windows for now, you can skip the *runtime* verification of this task and only do the compile check (with `OSXARM64` enabled in Project Options).

**Files:**
- Modify: `DX.DateChanger/src/DX.DateChanger.FileTime.pas` (add `TMacFileTimeSetter`)

- [ ] **Step 1: Add the macOS implementation**

Add `Macapi.Foundation, Macapi.ObjectiveC, Macapi.Helpers, Posix.SysTime, Posix.Errno` to the existing implementation `uses` clause behind `{$IFDEF MACOS}`. Then, between the Windows `{$ENDIF}` and the `CreateFileTimeSetter` factory, add:

```pascal
{$IFDEF MACOS}
type
  TMacFileTimeSetter = class(TInterfacedObject, IFileTimeSetter)
  public
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
  end;

procedure TMacFileTimeSetter.SetTimes(const APath: string; const AWhen: TDateTime);
var
  LMgr: NSFileManager;
  LAttrs: NSMutableDictionary;
  LDate: NSDate;
  LWhenUtc: TDateTime;
  LIntervalSince1970: Double;
  LNSPath: NSString;
  LErrorPtr: Pointer;
  LTimes: array[0..1] of timeval;
  LCPath: MarshaledAString;
  LRC: Integer;
begin
  LWhenUtc := TTimeZone.Local.ToUniversalTime(AWhen);
  // NSDate uses seconds since 1970-01-01 UTC
  LIntervalSince1970 := (LWhenUtc - EncodeDate(1970, 1, 1)) * SecsPerDay;
  LDate := TNSDate.Wrap(TNSDate.OCClass.dateWithTimeIntervalSince1970(LIntervalSince1970));

  LAttrs := TNSMutableDictionary.Create;
  try
    LAttrs.setValue(NSObjectToID(LDate), NSFileCreationDate);
    LAttrs.setValue(NSObjectToID(LDate), NSFileModificationDate);

    LMgr := TNSFileManager.Wrap(TNSFileManager.OCClass.defaultManager);
    LNSPath := StrToNSStr(APath);
    LErrorPtr := nil;
    if not LMgr.setAttributes(LAttrs, LNSPath, @LErrorPtr) then
      raise EFileTimeError.Create('NSFileManager.setAttributes failed', EACCES);

    // Touch atime via utimes (NSFileManager does not expose access time).
    LCPath := MarshaledAString(UTF8String(APath));
    LTimes[0].tv_sec  := Trunc(LIntervalSince1970);
    LTimes[0].tv_usec := 0;
    LTimes[1] := LTimes[0];
    LRC := utimes(LCPath, @LTimes[0]);
    if LRC <> 0 then
      raise EFileTimeError.Create('utimes failed', errno);
  finally
    LAttrs.release;
  end;
end;
{$ENDIF}
```

Update the factory:

```pascal
function CreateFileTimeSetter: IFileTimeSetter;
begin
{$IFDEF MSWINDOWS}
  Result := TWinFileTimeSetter.Create;
{$ELSEIF DEFINED(MACOS)}
  Result := TMacFileTimeSetter.Create;
{$ELSE}
  raise ENotImplemented.Create('No IFileTimeSetter for this platform');
{$ENDIF}
```

> **Reference for the Posix bindings used here:** `Posix.SysTime.utimes` is the standard signature; `timeval` is in `Posix.SysTime` as well. If your Delphi version names them differently, consult `Posix.Stdio` and `Posix.SysStat` for the correct unit names.

- [ ] **Step 2: Build for macOS target**

In Delphi IDE: switch active target platform to `macOS ARM 64-bit (Apple Silicon)`. Connect to PAServer.

Build the test project. Expected: builds with no errors.

- [ ] **Step 3: Deploy and run the smoke test on macOS**

In Delphi IDE: `Run > Run Without Debugging` (`Shift+Ctrl+F9`) with macOS as the active platform. PAServer deploys and runs the test executable on the Mac.

Expected: `SetTimes_Roundtrip_TimestampsMatchWithinOneSecond` passes.

If you do not have a Mac available now: build-only is acceptable; come back to this step when Mac access is available.

- [ ] **Step 4: Commit**

```bash
git add DX.DateChanger/src/DX.DateChanger.FileTime.pas
git commit -m "feat(dx.datechanger): add macOS IFileTimeSetter implementation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Main FMX project + FormMain (drop wiring + UI)

**Files:**
- Create: `DX.DateChanger/DX.DateChanger.dproj`
- Create: `DX.DateChanger/DX.DateChanger.dpr`
- Create: `DX.DateChanger/src/FormMain.pas`
- Create: `DX.DateChanger/src/FormMain.fmx`

- [ ] **Step 1: Create the main project via Delphi IDE**

`File > New > Multi-Device Application > Blank Application > OK`. Save:

- Form unit: `FormMain` (in `DX.DateChanger/src/`)
- Project: `DX.DateChanger.dproj` (in `DX.DateChanger/`)

In **Project > Options**:
- **Application > Appearance > Title**: `DX.DateChanger`
- **Building > Delphi Compiler > Output directory**: `build\$(Platform)\$(Config)`
- **Building > Delphi Compiler > Unit output directory**: `build\$(Platform)\$(Config)\dcu`
- **Building > Delphi Compiler > Search path**: add `src`
- **Description > Application > Target platforms**: `Win32`, `Win64`, `OSXARM64`
- **Application > Version Info**: tick `Include version information in project`. Set version to `1.0.0.0`. Copyright `Olaf Monien`.

- [ ] **Step 2: Replace `FormMain.fmx` with the layout**

Open `DX.DateChanger/src/FormMain.fmx`. Replace its content with:

```
object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'DX.DateChanger'
  ClientHeight = 320
  ClientWidth = 480
  FormFactor.Width = 480
  FormFactor.Height = 320
  FormFactor.Devices = [Desktop]
  BorderStyle = Single
  Position = ScreenCenter
  OnCreate = FormCreate
  object DropZone: TRectangle
    Align = Client
    Margins.Left = 16.0
    Margins.Top = 16.0
    Margins.Right = 16.0
    Margins.Bottom = 16.0
    Stroke.Dash = Dash
    Stroke.Color = claDarkgray
    Fill.Color = claWhitesmoke
    XRadius = 12.0
    YRadius = 12.0
    HitTest = True
    OnDragOver = DropZoneDragOver
    OnDragDrop = DropZoneDragDrop
    object LabelTitle: TLabel
      Align = Center
      Width = 400.0
      Height = 32.0
      TextSettings.HorzAlign = Center
      TextSettings.Font.Size = 18.0
      Text = 'Drop files here'
    end
    object LabelHint: TLabel
      Align = Bottom
      Margins.Bottom = 16.0
      Height = 24.0
      TextSettings.HorzAlign = Center
      TextSettings.Font.Size = 11.0
      TextSettings.FontColor = claGray
      Text = 'Filenames starting with YYYY-MM-DD will have their date set to that day, 10:00 local time.'
    end
    object LabelViewLog: TLabel
      Align = MostBottom
      Margins.Right = 8.0
      Margins.Bottom = 4.0
      Height = 18.0
      Visible = False
      TextSettings.HorzAlign = Trailing
      TextSettings.Font.Size = 10.0
      TextSettings.FontColor = claDodgerblue
      Cursor = crHandPoint
      Text = '[View log]'
      OnClick = LabelViewLogClick
    end
  end
  object RevertTimer: TTimer
    Enabled = False
    Interval = 5000
    OnTimer = RevertTimerTimer
  end
end
```

(Save with Delphi's text-form encoding default — `#<codepoint>` for non-ASCII, CRLF.)

- [ ] **Step 3: Replace `FormMain.pas`**

Replace `DX.DateChanger/src/FormMain.pas` with:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   FMX main form: a single drop zone with status feedback. Thin shell
  ///   over TDateChangerService.
  /// </summary>
  /// <remarks>
  ///   Holds no parsing or OS-specific code. Drop events are forwarded to
  ///   the service; the resulting TDropResult is rendered as a transient
  ///   counter line that reverts after 5 s.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit FormMain;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  FMX.Forms, FMX.Controls, FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Layouts,
  DX.DateChanger.FileTime, DX.DateChanger.Service;

type
  TMainForm = class(TForm)
    DropZone: TRectangle;
    LabelTitle: TLabel;
    LabelHint: TLabel;
    LabelViewLog: TLabel;
    RevertTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure DropZoneDragOver(Sender: TObject; const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
    procedure DropZoneDragDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    procedure RevertTimerTimer(Sender: TObject);
    procedure LabelViewLogClick(Sender: TObject);
  private
    FService: TDateChangerService;
    FLastLogPath: string;
    procedure ShowDefaultText;
    procedure ShowResult(const AResult: TDropResult);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
{$IFDEF MSWINDOWS}
  Winapi.ShellAPI, Winapi.Windows,
{$ENDIF}
{$IFDEF MACOS}
  Macapi.Foundation, Macapi.AppKit,
{$ENDIF}
  FMX.Platform;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FService := TDateChangerService.Create(CreateFileTimeSetter);
  ShowDefaultText;
end;

procedure TMainForm.ShowDefaultText;
begin
  LabelTitle.Text := 'Drop files here';
  LabelHint.Text := 'Filenames starting with YYYY-MM-DD will have their date set to that day, 10:00 local time.';
  LabelViewLog.Visible := False;
end;

procedure TMainForm.ShowResult(const AResult: TDropResult);
var
  LText: string;
begin
  LText := Format('Last drop: %d processed · %d skipped', [AResult.Processed, AResult.Skipped]);
  if AResult.Errors > 0 then
    LText := LText + Format(' · %d error', [AResult.Errors]);
  LabelTitle.Text := LText;
  LabelHint.Text := '';
  LabelViewLog.Visible := AResult.Errors > 0;
  FLastLogPath := AResult.LogPath;
  RevertTimer.Enabled := False;
  RevertTimer.Enabled := True;
end;

procedure TMainForm.DropZoneDragOver(Sender: TObject; const Data: TDragObject;
  const Point: TPointF; var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Move
  else
    Operation := TDragOperation.None;
end;

procedure TMainForm.DropZoneDragDrop(Sender: TObject; const Data: TDragObject;
  const Point: TPointF);
var
  LResult: TDropResult;
begin
  LResult := FService.ProcessDrop(Data.Files);
  ShowResult(LResult);
end;

procedure TMainForm.RevertTimerTimer(Sender: TObject);
begin
  RevertTimer.Enabled := False;
  ShowDefaultText;
end;

procedure TMainForm.LabelViewLogClick(Sender: TObject);
begin
  if FLastLogPath = '' then Exit;
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(FLastLogPath), nil, nil, SW_SHOWNORMAL);
{$ENDIF}
{$IFDEF MACOS}
  TNSWorkspace.Wrap(TNSWorkspace.OCClass.sharedWorkspace).openFile(StrToNSStr(FLastLogPath));
{$ENDIF}
end;

end.
```

- [ ] **Step 4: Update `DX.DateChanger.dpr`**

Replace `DX.DateChanger/DX.DateChanger.dpr` with:

```pascal
program DX.DateChanger;

uses
  System.StartUpCopy,
  FMX.Forms,
  FormMain in 'src\FormMain.pas' {MainForm},
  DX.DateChanger.Parser   in 'src\DX.DateChanger.Parser.pas',
  DX.DateChanger.FileTime in 'src\DX.DateChanger.FileTime.pas',
  DX.DateChanger.Service  in 'src\DX.DateChanger.Service.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
```

In Delphi IDE: also add the three `DX.DateChanger.*.pas` files via Project Manager → `Add...` so they appear in the `.dproj`.

- [ ] **Step 5: Build for Win64**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\DX.DateChanger.dproj -Platform Win64 -Config Debug
```

Expected: `DX.DateChanger.exe` produced at `DX.DateChanger/build/Win64/Debug/`.

- [ ] **Step 6: Manual UAT (Windows)**

Run `DX.DateChanger.exe`. Verify:

1. Window opens, ~480 × 320, non-resizable, centered, title `DX.DateChanger`.
2. Drop zone shows "Drop files here" + hint line.
3. Create a temp file `C:\Temp\2026-04-28 photo.txt` (any content). Drop onto drop zone.
4. Window updates to `Last drop: 1 processed · 0 skipped`.
5. After ~5 s the default text returns.
6. Right-click the file → Properties: `Created` and `Modified` show `2026-04-28 10:00:00` (local).
7. Drop a folder containing 2 matching files + 1 non-matching: counter reads `2 processed · 1 skipped`.
8. Make a file read-only and drop it: counter reads `0 processed · 1 skipped` (no error log).

If any of 1–8 fails: fix and re-run before committing.

- [ ] **Step 7: Commit**

```bash
git add DX.DateChanger/DX.DateChanger.dproj \
        DX.DateChanger/DX.DateChanger.dpr \
        DX.DateChanger/src/FormMain.pas \
        DX.DateChanger/src/FormMain.fmx
git commit -m "feat(dx.datechanger): add FMX main form with drop-zone wiring

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Cross-platform build verification + final UAT

- [ ] **Step 1: Build all targets**

```powershell
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\tests\DX.DateChangerTests.dproj -Platform Win64 -Config Debug
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\DX.DateChanger.dproj      -Platform Win32 -Config Debug
.\DX.DateChanger\build\DelphiBuildDPROJ.ps1 -ProjectFile .\DX.DateChanger\DX.DateChanger.dproj      -Platform Win64 -Config Debug
```

Mac (from Delphi IDE with PAServer connected):
- Switch active platform to `OSXARM64`.
- Build the test project — expect 0 errors.
- Build the main project — expect 0 errors.

- [ ] **Step 2: Run full DUnitX suite on Windows**

```powershell
.\DX.DateChanger\build\Win64\Debug\DX.DateChangerTests.exe --exitbehavior:Continue
```

Expected: all tests pass (≈ 33 tests: 22 parser + 10 service + 1 file-time smoke).

- [ ] **Step 3: Run full DUnitX suite on macOS**

Run via PAServer from Delphi IDE.

Expected: all tests pass.

- [ ] **Step 4: Manual UAT — both platforms**

Run through the acceptance criteria from §10 of the PRD on **both** Windows and macOS:

1. App launches; one window with drop zone + explanatory text.
2. Dropping `2026-04-28 photo.jpg` sets all three timestamps to `2026-04-28 10:00:00` local. Verify with OS file inspector.
3. Dropping `notes.txt` (no date prefix) leaves it untouched.
4. Folder drop processes only top-level matching files; subdirectories ignored.
5. `2026-13-45.txt` silently skipped (invalid date).
6. Counter line updates after each drop and reverts after ~5 s.
7. Read-only file: counts as skipped; no log line.
8. Force a non-permission error (e.g. drop a file from a network share that disconnects mid-write) → error count + `[View log]` link → click opens the log.
9. All DUnitX tests pass on both platforms.

- [ ] **Step 5: Tag the release commit**

```bash
git tag -a v1.0.0 -m "DX.DateChanger v1.0.0"
```

(Push the tag only when the user explicitly asks.)

- [ ] **Step 6: Final summary commit (if anything changed during UAT)**

If you fixed anything during UAT, commit those changes. Otherwise no final commit is needed — Tasks 1-7 cover the full feature.

---

## Self-review checklist (run after implementation)

Before declaring v1.0 done, walk through the PRD acceptance criteria one more time. Common failure modes to look for:

- **DST around the date:** if the target date crosses a DST boundary, does the local→UTC conversion still yield exactly 10:00 local on the file inspector? Manual check: drop a file dated for a date inside DST and one outside, on a timezone that observes DST.
- **macOS network volumes:** `NSFileManager.setAttributes` on SMB / network shares can silently no-op for `NSFileCreationDate`. Add to known limitations in `docs/README.md` if you hit this.
- **Long paths on Windows:** if `CreateFileW` returns `ERROR_PATH_NOT_FOUND` for paths > 260 chars, document the limit (do not fix in v1.0; out of scope).
- **Memory leaks:** the test runner calls `ReportMemoryLeaksOnShutdown := True`. Watch for "Unexpected Memory Leak" dialog at the end of test runs.

---

## Plan complete

When all tasks are checked off:

1. Update `DX.DateChanger/docs/README.md` with a short usage guide and one screenshot per platform.
2. Open a PR — `feat(dx.datechanger): v1.0`.
3. Merge.
