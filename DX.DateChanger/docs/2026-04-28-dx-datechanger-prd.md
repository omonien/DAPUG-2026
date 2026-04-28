# DX.DateChanger — Product Requirements Document (PRD)

**Version:** 1.0 (design)
**Date:** 2026-04-28
**Author:** Olaf Monien
**Status:** Approved for implementation
**License:** MIT — Copyright (c) 2026 Olaf Monien
**Project language:** English (uniform across code, comments, docs, commits)

---

## 1. Purpose

`DX.DateChanger` is a small cross-platform desktop utility for **Windows** and
**macOS** that normalizes file timestamps based on the date encoded in a
filename. When a file whose name starts with `YYYY-MM-DD` is dropped onto the
app, the tool sets that file's **creation time**, **modification time**, and
**access time** to that calendar date at **10:00 local time**. Files whose
names do not match the pattern are silently ignored.

The tool serves two purposes:

1. **Utility** — quick, friction-free way to file scanned/dated documents
   whose timestamps don't match the date in their filename.
2. **Workshop demo** — a teaching artifact for the DAPUG 2026 "Everything AI"
   workshop, showing clean Delphi/FMX structure, cross-platform drag-and-drop,
   OS-specific file APIs, and DUnitX testing in a small but real project.

## 2. Target platform & toolchain

| Item             | Choice                                                  |
|------------------|---------------------------------------------------------|
| IDE / compiler   | Delphi 12 Athens                                        |
| UI framework     | FireMonkey (FMX)                                        |
| Targets          | `Win64` (primary), `Win32` (secondary), `OSX64ARM`      |
| Test framework   | DUnitX (Git submodule under `libs/DUnitX/`)             |
| Build tool       | `DelphiBuildDPROJ.ps1` from `omonien/DelphiStandards`   |
| Code signing     | None (unsigned builds for both platforms)               |
| Distribution     | Plain `.exe` on Windows, plain `.app` bundle on macOS   |

## 3. User experience

### 3.1 Window

- Single fixed-size window, **480 × 320 px**, **non-resizable**, centered on
  first launch.
- Window title: `DX.DateChanger`.
- One control fills the client area: the **drop zone**.
- No menus. No buttons. No settings dialog. No preferences window.

### 3.2 Drop zone — visual states

| State            | Visual                                                                                  |
|------------------|-----------------------------------------------------------------------------------------|
| Default          | Rounded rectangle with dashed/soft border, neutral fill                                 |
| Hover (drag-in)  | Border solidifies, fill tints with accent color                                         |
| Drop accepted    | Brief tint pulse (~200 ms)                                                              |
| After drop       | Counter line replaces explanatory text (see 3.4); reverts after 5 s or on next drop     |
| After drop+errors| Counter line includes error count; small `[View log]` link appears in bottom-right      |

### 3.3 Drop zone — text content

**Default state — two centered lines:**

- Line 1, large: `Drop files here`
- Line 2, small, dimmed: `Filenames starting with YYYY-MM-DD will have their date set to that day, 10:00 local time.`

### 3.4 Counter line (post-drop)

```
Last drop: 7 processed · 3 skipped
```

With errors:

```
Last drop: 5 processed · 2 skipped · 1 error    [View log]
```

- `processed` — files that matched the pattern and whose timestamps were
  successfully written.
- `skipped` — files that did not match the pattern (no date prefix, invalid
  date, or non-file entries inside dropped folders).
- `error` — files that matched but whose timestamps could not be written.
- The `[View log]` link is shown only when `errors > 0`. Clicking it opens the
  log file in the OS default text editor.

### 3.5 Localization

UI strings are in **English only**. No localization or translation in v1.0.

## 4. Domain rules

### 4.1 Filename matching

A file's basename (last path segment, **including** any extension) is checked
against the pattern. A match requires **all** of:

- Length ≥ 10 characters.
- Characters at positions 1–4 are decimal digits (year `0001..9999`).
- Character at position 5 is `-`.
- Characters at positions 6–7 are decimal digits forming month `01..12`.
- Character at position 8 is `-`.
- Characters at positions 9–10 are decimal digits forming day `01..31`,
  **and** the resulting `(YYYY, MM, DD)` triple is a valid Gregorian calendar
  date (leap years respected).
- Character at position 11 (if the basename is longer than 10 characters) is
  unrestricted.

Examples (basename → result):

| Basename                  | Match? | Notes                                  |
|---------------------------|--------|----------------------------------------|
| `2026-04-28.jpg`          | Yes    |                                        |
| `2026-04-28 photo.jpg`    | Yes    |                                        |
| `2026-04-28_note.txt`     | Yes    |                                        |
| `2026-04-28abc.txt`       | Yes    | char 11 is unrestricted                |
| `2026-04-28`              | Yes    | exactly 10 chars, no extension         |
| `notes-2026-04-28.txt`    | No     | date is not at the start               |
| `2026-13-45.txt`          | No     | invalid date                           |
| `2026-02-30.txt`          | No     | invalid date (leap-year aware)         |
| `2026/04/28.txt`          | No     | wrong separator                        |
| `26-04-28.txt`            | No     | year not 4 digits                      |
| `notes.txt`               | No     |                                        |

Invalid date strings produce a silent **skip**, not an error.

### 4.2 Drop scope

- **Files** dropped directly: each is evaluated and either processed or
  skipped.
- **Folders** dropped: top-level entries are enumerated; subdirectories are
  **not** recursed; matching files within the top level are processed,
  non-matching files are skipped.
- **Symlinks / macOS aliases**: followed — the resolved target's timestamps
  are modified.
- **Multiple items** in a single drop: all are processed in order; the
  counter aggregates the entire drop.
- **Read-only / locked files**: silently **skipped** and counted as
  `Skipped` (no attempt to clear the read-only flag, no log entry). A write
  failure whose OS error code indicates "access denied / read-only"
  (`ERROR_ACCESS_DENIED` on Windows, `EACCES` on macOS) is treated as a
  skip; any other write failure is treated as an error.
- **File already at the target timestamp**: rewritten anyway (idempotent —
  no detection of "no change needed").

### 4.3 Timestamps written

- Date = the parsed `YYYY-MM-DD`.
- Time = `10:00:00.000` **local time** (DST resolved by Delphi's standard
  `TTimeZone.Local`).
- All three timestamps are set to the same instant:
  - **Creation time** (a.k.a. birth time)
  - **Modification time** (last write)
  - **Access time** (last access)

### 4.4 Error logging

- Log path:
  - Windows: `%LOCALAPPDATA%\DX.DateChanger\errors.log`
  - macOS:   `~/Library/Application Support/DX.DateChanger/errors.log`
- Created lazily on the first error.
- Append-only. One line per error:
  `<ISO-8601 local timestamp>  TAB  <full file path>  TAB  <OS error code>  TAB  <message>`
- The `[View log]` link in the UI opens this file with the OS default text
  editor.

## 5. Architecture

Four units across three layers. Arrows = "depends on".

```
       ┌─────────────────────┐
       │    FormMain.pas     │   FMX form, drop event handlers, label updates
       │      (UI)           │
       └──────────┬──────────┘
                  │ uses
                  ▼
       ┌─────────────────────┐
       │ DX.DateChanger.     │   orchestrator: TArray<string> → TDropResult
       │   Service.pas       │   iterates, calls Parser, calls IFileTimeSetter
       └──┬──────────────┬───┘
          │ uses         │ uses
          ▼              ▼
  ┌───────────────┐  ┌─────────────────────────┐
  │ DX.DateChanger│  │ DX.DateChanger.FileTime │  interface + Win/macOS
  │  .Parser.pas  │  │   .pas                  │  implementations ($IFDEF)
  └───────────────┘  └─────────────────────────┘
```

### 5.1 `DX.DateChanger.Parser.pas`

Pure functions, no I/O, no platform code, fully unit-testable.

```pascal
type
  TParseResult = record
    Matched: Boolean;
    Date: TDate;        // valid only when Matched = True
  end;

function TryParseFilenameDate(const AFileName: string): TParseResult;
```

### 5.2 `DX.DateChanger.FileTime.pas`

Defines an interface seam and provides one OS-specific implementation per
platform, selected at compile time.

```pascal
type
  EFileTimeError = class(Exception)
  public
    OSErrorCode: Integer;   // GetLastError on Windows, errno on macOS
  end;

  IFileTimeSetter = interface
    ['{...GUID...}']
    procedure SetTimes(const APath: string; const AWhen: TDateTime);
    // raises EFileTimeError on failure (with OSErrorCode populated)
  end;

function CreateFileTimeSetter: IFileTimeSetter;
```

- `{$IFDEF MSWINDOWS}` — `TWinFileTimeSetter` uses Win32 `CreateFileW` +
  `SetFileTime`, writing all three of `ftCreationTime`, `ftLastAccessTime`,
  `ftLastWriteTime`.
- `{$IFDEF MACOS}` — `TMacFileTimeSetter` uses Cocoa
  `NSFileManager defaultManager setAttributes:ofItemAtPath:error:` with
  `NSFileCreationDate` + `NSFileModificationDate`, plus POSIX `utimes()` for
  access time consistency.

### 5.3 `DX.DateChanger.Service.pas`

Orchestration. Pure logic above the I/O seam (no FMX, no platform code).

```pascal
type
  TDropResult = record
    Processed: Integer;
    Skipped:   Integer;
    Errors:    Integer;
    LogPath:   string;   // populated only when Errors > 0
  end;

  TDateChangerService = class
  public
    constructor Create(const ATimeSetter: IFileTimeSetter);
    function ProcessDrop(const APaths: TArray<string>): TDropResult;
  end;
```

Algorithm of `ProcessDrop`:

1. For each input path:
   - If it is a directory: enumerate its top-level entries (files only,
     non-recursive) and treat each as an input file.
   - If it is a file: continue with step 2.
   - Otherwise (does not exist): increment `Errors`, log, continue.
2. Run `TryParseFilenameDate(ExtractFileName(path))`.
3. If not matched: increment `Skipped`, continue.
4. Build target `TDateTime` = `LParsed.Date + EncodeTime(10, 0, 0, 0)`.
5. Call `ATimeSetter.SetTimes(path, target)`.
6. On success: increment `Processed`. On `EFileTimeError`:
   - if the underlying OS error code indicates access-denied / read-only
     (`ERROR_ACCESS_DENIED` on Windows, `EACCES` on macOS), increment
     `Skipped` and continue without logging;
   - otherwise increment `Errors`, append a line to the error log, and
     continue.
7. Return aggregate `TDropResult`.

### 5.4 `FormMain.pas` / `FormMain.fmx`

Thin shell. Owns one `TDateChangerService` (constructed with
`CreateFileTimeSetter`). Wires FMX `OnDragOver` / `OnDragDrop` events to
`Service.ProcessDrop`. Formats the resulting `TDropResult` into the counter
line, schedules the 5 s revert via `TTimer`, shows or hides the
`[View log]` link, and opens the log file via OS default editor when the
link is clicked.

The form contains **no parsing logic and no OS-specific time API code**.

## 6. Project layout

```
DX.DateChanger/
├── DX.DateChanger.dproj
├── DX.DateChanger.dpr
├── src/
│   ├── DX.DateChanger.Parser.pas
│   ├── DX.DateChanger.FileTime.pas
│   ├── DX.DateChanger.Service.pas
│   ├── FormMain.pas
│   └── FormMain.fmx
├── tests/
│   ├── DX.DateChangerTests.dproj
│   ├── DX.DateChangerTests.dpr
│   ├── DX.DateChanger.Parser.Tests.pas
│   ├── DX.DateChanger.Service.Tests.pas
│   └── DX.DateChanger.FileTime.Tests.pas
├── libs/
│   └── DUnitX/                        # git submodule (VSoftTechnologies/DUnitX)
├── build/                             # output, gitignored
└── docs/
    ├── 2026-04-28-dx-datechanger-prd.md   # this document
    └── README.md                          # short usage + screenshots (later)
```

### 6.1 Conventions (from `Delphi.md`)

- Encoding: `.pas` UTF-8 BOM, `.fmx` `#<codepoint>`, CRLF for all
  text files (already enforced by repo `.gitattributes`).
- Naming: `T` for classes, `I` for interfaces, `E` for exceptions; `L` for
  locals, `F` for fields, `A` for parameters; `c` / `sc` / `rs` for
  constants; PascalCase throughout.
- Scoped enums via `{$SCOPEDENUMS ON}` where defined.
- Each `.pas` ships with the standard XML-doc unit header
  (`<summary>` / `<remarks>` / `<copyright>`), copyright Olaf Monien 2026,
  MIT.
- Output paths: `build/$(Platform)/$(Config)` for binaries,
  `build/$(Platform)/$(Config)/dcu` for DCUs.

## 7. Tests (DUnitX)

| Unit              | Strategy                                                                           | Approx. count |
|-------------------|------------------------------------------------------------------------------------|---------------|
| `Parser`          | Pure unit tests, table-driven                                                      | ~15 cases     |
| `Service`         | Unit tests with `TMockFileTimeSetter` (records calls, configurable to throw)       | ~10 cases     |
| `FileTime`        | Smoke test: create temp file, call `SetTimes`, read back via `TFile.GetCreationTime` / `GetLastWriteTime`, assert within 1-second tolerance | 1 per platform |
| `FormMain`        | Not unit tested (thin shell)                                                       | 0             |

### 7.1 Parser test cases (illustrative)

- Valid: `2026-04-28.jpg`, `2026-04-28 photo.jpg`, `2026-04-28abc.txt`,
  `2026-04-28` (exactly 10 chars).
- Leap year: `2024-02-29.txt` matches; `2026-02-29.txt` does not.
- Invalid date: `2026-13-01.txt`, `2026-00-15.txt`, `2026-02-30.txt`,
  `2026-04-31.txt`.
- Wrong shape: `26-04-28.txt`, `2026/04/28.txt`, `notes-2026-04-28.txt`,
  empty string.

### 7.2 Service test cases (illustrative)

- Mixed batch: 3 matching files + 2 non-matching → `Processed=3, Skipped=2`.
- Folder drop: top-level files only; subfolders ignored.
- Mock raises `EFileTimeError` → `Errors` incremented, log line written,
  remaining files still processed.
- Empty drop → all counters zero.
- Non-existent path in input → counted as error.

### 7.3 Tooling

- DUnitX added as a Git submodule at `DX.DateChanger/libs/DUnitX/` from
  `VSoftTechnologies/DUnitX`.
- Test project compiles as a console application using the standard DUnitX
  text reporter; runnable from CLI or IDE.

## 8. Build & versioning

- Configurations: `Debug`, `Release`.
- VersionInfo enabled (`IncludeVerInfo=True`) in DPROJ; initial version
  **`1.0.0.0`**, copyright `Olaf Monien`.
- Ad-hoc CLI builds via `DelphiBuildDPROJ.ps1` placed in
  `DX.DateChanger/build/` (per `Delphi.md` standard).
- Output binaries (unsigned):
  - Windows: `DX.DateChanger.exe`
  - macOS:   `DX.DateChanger.app` bundle
- No installer, no DMG packaging, no auto-update mechanism in v1.0.

## 9. Out of scope (v1.0)

The following are explicitly excluded from v1.0 and may appear in later
versions:

- Recursive folder processing
- Configurable target time (always 10:00)
- Configurable matcher (always strict `YYYY-MM-DD` prefix)
- Date sources other than the filename (EXIF, sidecar files, etc.)
- Undo / dry-run preview
- Internationalization
- Code signing & notarization (Apple Developer ID, Authenticode)
- Auto-update
- Settings or preferences persistence
- Dark-mode aware theming beyond what FMX gives by default

## 10. Acceptance criteria (v1.0 ship test)

The release is ready when, on **both** Windows and macOS:

1. The app launches showing one window with the drop zone and explanatory
   text.
2. Dropping `2026-04-28 photo.jpg` sets all three timestamps to
   `2026-04-28 10:00:00` local. Verified via OS file inspector.
3. Dropping `notes.txt` (no date prefix) leaves it untouched.
4. Dropping a folder with mixed contents processes only top-level matching
   files and ignores subdirectories.
5. Dropping `2026-13-45.txt` is silently skipped (invalid date).
6. The counter line updates after each drop and reverts to the default
   explanatory text after ~5 s.
7. Forcing a write error (e.g. read-only file) increments the error
   counter, writes a line to the log file, and shows the `[View log]`
   link, which opens the log file in the OS default text editor.
8. All DUnitX tests pass on both platforms (`Win64` and `OSX64ARM`).

## 11. Open items

None at design freeze. Implementation may surface platform-specific issues
(particularly around macOS `NSFileManager` attribute behavior on
network-mounted volumes); these will be tracked as implementation tasks
rather than design changes.
