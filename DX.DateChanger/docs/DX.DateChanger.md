# DX.DateChanger — Technical Documentation

A minimalistic Delphi FireMonkey utility for Windows and macOS that rewrites a
file's creation, modification, and access timestamps based on a `YYYY-MM-DD`
prefix in the filename.

- **Author:** Olaf Monien
- **License:** MIT (see unit headers)
- **Targets:** Win64, OSXARM64 (FireMonkey, RTL only — no third-party runtime
  dependencies)
- **Tests:** DUnitX (vendored as a Git submodule under [libs/DUnitX/](../libs/DUnitX/))

---

## 1. Purpose & user-visible behavior

The user drags one or more files (or a folder) onto a single drop zone. For
every file whose **basename** starts with a strict, calendar-valid
`YYYY-MM-DD`, the tool sets

- creation time
- modification time
- access time (where the OS exposes it)

to **that date at 10:00 local time**. Files that do not match the pattern, or
whose date is not a valid Gregorian date, are silently skipped — they are
**never** modified.

After each drop the form briefly shows
`Last drop: N processed · M skipped [· K error]`
and reverts to the default hint text after 5 seconds. If errors occurred, a
clickable "View log" label is shown that opens the per-user error log.

The motivation, scope, and acceptance criteria are captured in
[2026-04-28-dx-datechanger-prd.md](2026-04-28-dx-datechanger-prd.md); the
phase plan is in [2026-04-28-dx-datechanger-plan.md](2026-04-28-dx-datechanger-plan.md);
the original brief is [Initial Idea.md](Initial%20Idea.md).

---

## 2. Filename pattern — exact contract

Implemented in [DX.DateChanger.Parser.pas](../src/DX.DateChanger.Parser.pas).

A basename matches **iff**:

| Position (1-based) | Requirement                              |
| ------------------ | ---------------------------------------- |
| 1..4               | digits — year, must be ≥ 1               |
| 5                  | literal `-`                              |
| 6..7               | digits — month                           |
| 8                  | literal `-`                              |
| 9..10              | digits — day                             |
| 11..end            | unrestricted (extension, suffix, empty)  |

Additionally, `(year, month, day)` must be a valid Gregorian date
(`System.SysUtils.TryEncodeDate` decides this — it correctly handles
leap years).

### Examples

| Input filename                       | Matched | Parsed date  | Notes                          |
| ------------------------------------ | ------- | ------------ | ------------------------------ |
| `2026-04-28.jpg`                     | yes     | 2026-04-28   |                                |
| `2026-04-28 photo.jpg`               | yes     | 2026-04-28   | space at position 11 is fine   |
| `2026-04-28abc.txt`                  | yes     | 2026-04-28   | letters at position 11 are fine|
| `2026-04-28`                         | yes     | 2026-04-28   | exactly 10 chars               |
| `2024-02-29.txt`                     | yes     | 2024-02-29   | leap year                      |
| `2026-02-29.txt`                     | no      | —            | non-leap year                  |
| `2026-13-01.txt`                     | no      | —            | invalid month                  |
| `2026-04-31.txt`                     | no      | —            | invalid day                    |
| `0000-04-28.txt`                     | no      | —            | year < 1                       |
| `notes-2026-04-28.txt`               | no      | —            | date not at start              |
| `26-04-28.txt`                       | no      | —            | 2-digit year                   |
| `2026/04/28.txt`, `2026.04.28.txt`   | no      | —            | only `-` is accepted           |
| `2O26-04-28.txt` (letter O)          | no      | —            | non-digit in date region       |

The full path is accepted but only the **basename**
(`System.IOUtils.TPath.GetFileName`) is inspected. The extension, if any, has
no influence beyond the position-11 rule.

The full test matrix lives in
[DX.DateChanger.Parser.Tests.pas](../tests/DX.DateChanger.Parser.Tests.pas).

---

## 3. Architecture

```
┌──────────────────────────────────────┐
│ FormMain (FMX)                       │   thin shell, drag&drop, status text
│  └─ TDateChangerService              │
│        ├─ TryParseFilenameDate ──────┼─► DX.DateChanger.Parser    (pure)
│        └─ IFileTimeSetter  ──────────┼─► DX.DateChanger.FileTime  (per-OS)
│             ├─ TWinFileTimeSetter    │      Winapi.SetFileTime
│             └─ TMacFileTimeSetter    │      NSFileManager + utimes
└──────────────────────────────────────┘
```

Three responsibilities, three units, one form:

| Unit                                                                       | Role                                                  | I/O    |
| -------------------------------------------------------------------------- | ----------------------------------------------------- | ------ |
| [DX.DateChanger.Parser.pas](../src/DX.DateChanger.Parser.pas)              | Pure functional date-prefix parser                    | none   |
| [DX.DateChanger.FileTime.pas](../src/DX.DateChanger.FileTime.pas)          | `IFileTimeSetter` abstraction + Win/Mac implementations | OS API |
| [DX.DateChanger.Service.pas](../src/DX.DateChanger.Service.pas)            | Orchestrator: walks paths, parses, writes, logs       | FS     |
| [FormMain.pas](../src/FormMain.pas) / [FormMain.fmx](../src/FormMain.fmx)  | FMX UI shell, drag&drop, transient status             | UI     |

This layering enables 100 % unit-testable orchestration (the service is
constructed against a mock `IFileTimeSetter`) and full platform isolation
(only `DX.DateChanger.FileTime` contains `{$IFDEF MSWINDOWS}` /
`{$IFDEF MACOS}` blocks for time-setting code; the service has a small ifdef
only for the access-denied error code constant and the per-OS log directory).

---

## 4. Public API reference

### 4.1 `DX.DateChanger.Parser`

```pascal
type
  TParseResult = record
    Matched: Boolean;
    Date: TDate;
  end;

function TryParseFilenameDate(const AFileName: string): TParseResult;
```

- Pure function. No exceptions on bad input — non-matching basenames return
  `Matched := False` and `Date := 0`.
- Accepts a basename or a full path; only the basename is inspected.
- Calendar validation: leap years, month range 1..12, day range respecting
  month length, year ≥ 1.

### 4.2 `DX.DateChanger.FileTime`

```pascal
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
```

- `SetTimes` writes creation, modification, and access timestamps to `APath`,
  setting all three to `AWhen` (interpreted as **local** time — the
  implementations convert to UTC internally).
- On failure, raises `EFileTimeError` with `OSErrorCode` populated:
  - Windows: `GetLastError` value (e.g., `ERROR_ACCESS_DENIED = 5`)
  - macOS: `errno` (e.g., `EACCES = 13`)
- `CreateFileTimeSetter` returns the platform-default implementation. On
  unsupported platforms it raises `ENotImplemented`.

#### Windows implementation — `TWinFileTimeSetter`

1. `CreateFileW(..., GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,
   nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)` — opens an existing file
   handle for writing while still allowing concurrent reads.
2. `TTimeZone.Local.ToUniversalTime(AWhen)` → `DateTimeToSystemTime` →
   `SystemTimeToFileTime`.
3. `SetFileTime(handle, @ft, @ft, @ft)` — creation, last-access,
   last-write all set to the same UTC `FILETIME`.
4. `CloseHandle` in `finally`.

#### macOS implementation — `TMacFileTimeSetter`

1. Convert local `TDateTime` → UTC → seconds since 1970-01-01 → `NSDate`.
2. Build an `NSMutableDictionary` with `NSFileCreationDate` and
   `NSFileModificationDate` and call
   `NSFileManager.defaultManager.setAttributes:ofItemAtPath:error:`.
3. Call POSIX `utimes(path, [atime, mtime])` for the access time, since
   `NSFileManager` does not expose it.
4. Failures raise `EFileTimeError` with `EACCES` or `errno`.

### 4.3 `DX.DateChanger.Service`

```pascal
type
  TDropResult = record
    Processed: Integer;
    Skipped:   Integer;
    Errors:    Integer;
    LogPath:   string;
  end;

  TDateChangerService = class
  public
    constructor Create(const ATimeSetter: IFileTimeSetter);
    function ProcessDrop(const APaths: TArray<string>): TDropResult;
  end;
```

- **Constructor injection** — the caller chooses the `IFileTimeSetter`. The
  app uses `CreateFileTimeSetter`; tests use `TMockFileTimeSetter`.
- `ProcessDrop` iterates `APaths`. For each entry:
  - If it is a directory, `TDirectory.GetFiles(path)` enumerates **top-level
    files only** — subdirectories are intentionally not recursed.
  - Otherwise the path is treated as a single file.
- For each file the service:
  1. Verifies existence (`TFile.Exists`). Missing → `Errors`, logged.
  2. Calls `TryParseFilenameDate`. No match → `Skipped`, no log entry.
  3. Computes `LWhen := matched-date + EncodeTime(10, 0, 0, 0)`.
  4. Calls `FTimeSetter.SetTimes(APath, LWhen)`.
     - Success → `Processed`.
     - `EFileTimeError` with access-denied code → `Skipped` (intentional;
       see counter rules).
     - Any other `EFileTimeError` → `Errors`, logged.
- `LogPath` is populated **only if `Errors > 0`** and points at the log file
  described below.

#### Counter semantics

| Outcome                                   | Counter     | Logged? |
| ----------------------------------------- | ----------- | ------- |
| Filename matches and timestamps written   | `Processed` | no      |
| Filename does not match the pattern       | `Skipped`   | no      |
| Filename matches but file is access-denied| `Skipped`   | no      |
| File does not exist                       | `Errors`    | yes     |
| Other OS failure on `SetTimes`            | `Errors`    | yes     |

Access-denied is deliberately a `Skipped` (not an error): on macOS it is the
common, expected outcome for files outside the user's sandbox grant, and the
PRD treats it as a silent no-op rather than a failure.

#### Error log

| Aspect    | Value |
|-----------|-------|
| Location (Windows) | `%USERPROFILE%\DX.DateChanger\errors.log` |
| Location (macOS)   | `~/Library/Application Support/DX.DateChanger/errors.log` |
| Mode      | append |
| Format    | tab-separated: `<ISO-8601 timestamp>\t<path>\t<os-error-code>\t<message>` |

The directory is created on demand. The path is exposed via
`TDropResult.LogPath` so the UI can offer a "View log" link.

---

## 5. UI flow

[FormMain.pas](../src/FormMain.pas) — single-form FMX shell. The form has no
parsing or OS code: it constructs a `TDateChangerService` in `FormCreate` and
forwards drop events.

| Element       | Type           | Role                                                                 |
| ------------- | -------------- | -------------------------------------------------------------------- |
| `DropZone`    | `TRectangle`   | Drag target. `OnDragOver` accepts the operation iff `Length(Data.Files) > 0`. `OnDragDrop` copies `Data.Files` into a `TArray<string>` and calls `FService.ProcessDrop`. |
| `LabelTitle`  | `TLabel`       | Default text `Drop files here`; replaced after a drop with `Last drop: N processed · M skipped [· K error]`. |
| `LabelHint`   | `TLabel`       | Hint text explaining the rule.                                       |
| `LabelViewLog`| `TLabel`       | Visible only when the last drop produced errors; click opens `FLastLogPath` via `ShellExecute` (Windows) or `NSWorkspace.openFile` (macOS). |
| `RevertTimer` | `TTimer`       | Single-shot pattern: disabled→enabled to restart; `OnTimer` reverts to the default text and disables itself. |

The lifecycle:

```
FormCreate → TDateChangerService.Create(CreateFileTimeSetter)
DragOver   → accept iff files
DragDrop   → ProcessDrop → ShowResult → restart RevertTimer (5 s)
RevertTimer→ ShowDefaultText
FormDestroy→ FreeAndNil(FService)
```

---

## 6. Project layout

```
DX.DateChanger/
├── DX.DateChanger.dpr            FMX program: FormMain + 3 units
├── DX.DateChanger.dproj          Win64 + OSXARM64 targets, build output to /build
├── src/
│   ├── FormMain.pas / .fmx       UI shell
│   ├── DX.DateChanger.Parser.pas
│   ├── DX.DateChanger.FileTime.pas
│   └── DX.DateChanger.Service.pas
├── tests/
│   ├── DX.DateChangerTests.dpr   DUnitX console runner
│   ├── DX.DateChanger.Parser.Tests.pas
│   ├── DX.DateChanger.Service.Tests.pas
│   └── DX.DateChanger.FileTime.Tests.pas
├── build/                        compiler output: $(platform)/$(config)[/dcu]
├── libs/DUnitX/                  Git submodule
└── docs/
    ├── Initial Idea.md
    ├── 2026-04-28-dx-datechanger-prd.md
    ├── 2026-04-28-dx-datechanger-plan.md
    └── DX.DateChanger.md         (this file)
```

---

## 7. Build & run

### 7.1 Application

Open `DX.DateChanger.dproj` in RAD Studio and build for **Win64** or
**OSXARM64**. Output goes to
`build/$(Platform)/$(Config)/DX.DateChanger.exe` (or `.app` on macOS).

The project uses no third-party runtime packages — only RTL/FMX, plus
`Winapi.Windows`/`Winapi.ShellAPI` on Windows and the
`Macapi.Foundation`/`Macapi.AppKit`/`Posix.SysTime` units on macOS, all
shipped with Delphi.

### 7.2 Tests

```
DX.DateChangerTests.dproj  →  build  →  build\Win64\Debug\DX.DateChangerTests.exe
```

Console runner; exit code is non-zero on any failure. Test fixtures:

| Fixture            | Coverage                                                              |
| ------------------ | --------------------------------------------------------------------- |
| `TParserTests`     | Strict YYYY-MM-DD shape, leap-year math, calendar validation, full-path basename extraction. Pure, no I/O. |
| `TServiceTests`    | Orchestration with a mock `IFileTimeSetter`: empty drops, single match, single non-match, mixed batches, exact 10:00 local time, top-level-only directory walking, access-denied → Skipped, other error → Error + log path populated, missing file → Error. |
| `TFileTimeTests`   | Smoke tests against the real OS (creates a temp file, sets times, reads them back). Platform-gated. |

The mock setter (`TMockFileTimeSetter`) records every call and can be
configured to throw a specific `EFileTimeError` for a given path or for all
calls, which is how the access-denied branch is exercised without touching
the file system.

---

## 8. Design decisions worth knowing

| Decision | Rationale |
| -------- | --------- |
| Strict 10-char prefix (no regex)            | Keeps the parser allocation-free and trivially auditable. The format is fixed by spec — there is no need for a regex engine. |
| `TryEncodeDate` for calendar validity       | Delegates leap-year handling to the RTL; we do not maintain a date table. |
| `IFileTimeSetter` interface + factory       | Lets the orchestrator be 100 % unit-testable on any platform with a mock; isolates `{$IFDEF}` blocks to one unit. |
| Access-denied counted as `Skipped`          | Matches the PRD: the tool is a no-op for files it cannot touch, not an error condition. macOS sandbox denials are routine. |
| Top-level-only directory walking            | Avoids surprise: dropping a folder must not silently rewrite times deep in a tree. |
| Set creation, modification *and* access     | Some workflows (photo importers, backup tools) read access time; setting it together avoids partial-state surprises. |
| Local-to-UTC conversion in the setter       | The user thinks in local time ("the 28th at 10 a.m. *here*"); the OS APIs want UTC. The conversion lives next to the API call. |
| Per-user log under HOME / Application Support | Avoids `Program Files` / system paths that need elevation; one file per user is enough for this volume. |
| 5-second revert of the status line          | The result is informational, not a dialog the user has to dismiss. |
