# Delphi Project Rules

Canonical reference for all Delphi rules. Referenced from [`CLAUDE.md`](./CLAUDE.md).

## Agent Behavior on Existing Projects

Before any modification of an existing Delphi project, scan for deviations from the rule set:
- Wrong encoding/BOM/line endings
- Missing or non-Delphi `.gitignore`/`.gitattributes`
- Output paths not matching `/build/$(platform)/$(config)`
- Naming or style violations
- Incomplete VersionInfo

If deviations are found: **do not modify autonomously.** Ask the user — (a) auto-correct or (b) only document and report? Modify only after explicit confirmation.

## 1. File Encoding

| File | Encoding | Note |
|---|---|---|
| `.pas` | UTF-8 with BOM | Required for umlauts/special chars |
| `.dfm`, `.fmx` | Codepoint syntax `#<n>` | e.g. `#196` for `Ä` |
| All source files | CRLF | LF causes parser/build errors |

## 2. Coding Style

Authoritative reference: [Delphi Style Guide EN](https://github.com/omonien/DelphiStandards/blob/master/Delphi%20Style%20Guide%20EN.md). Place a local copy at `docs/Delphi Style Guide EN.md`.

### 2.1 Naming Conventions

PascalCase throughout.

**Units**
- Hierarchical dot notation
- Forms: `*.Form.pas` · Data Modules: `*.DM.pas`
- Filename = unit name
- Example: `Customer.Details.Form.pas`

**Types**

| Kind | Prefix | Example |
|---|---|---|
| Class | `T` | `TCustomer` |
| Interface | `I` | `ILogger` |
| Record | `T` | `TPoint3D` |
| Exception | `E` | `EInvalidOperation` |
| Enum | `T` | `TOrderStatus` |

**Variables**

| Scope | Prefix | Example |
|---|---|---|
| Local | `L` | `LUserName` |
| Field | `F` | `FConnectionString` |
| Global | `G` | `GAppConfig` (avoid) |
| Loop counter | – | `i`, `j`, `k` |

**Constants**

| Kind | Prefix | Example |
|---|---|---|
| General | `c` | `cMaxRetries` |
| String | `sc` | `scErrorMessage` |
| Resource string | `rs` | `rsWelcomeText` |
| System-level | ALL_CAPS | `APP_VERSION` |

**Parameters**
- `A` + PascalCase: `AValue`, `AUserID`
- `const` for immutable; `var`/`out` explicit for output

**Methods**
- Procedures: verb prefix (`SaveDocument`, `ValidateUserInput`)
- Functions: `Get`/`Is`/`Can` prefix (`GetUserName`, `IsValid`, `CanExecute`)

**Components**
- Component-type prefix: `ButtonLogin`, `EditUserName`, `GridCustomers`
- No `F`/`L`/`G` on component instances

**Forms / Data Modules**

| Kind | Class name | Instance name |
|---|---|---|
| Form | `TForm` + context (`TFormMain`) | without `T` (`FormMain`) |
| Data Module | `TDM` + context (`TDMCustomerDetails`) | without `T` (`DMCustomerDetails`) |

### 2.2 Enums — Scoped Only

All enums MUST be scoped:

```pascal
{$SCOPEDENUMS ON}
type
  TOrderStatus = (Created, Confirmed, Shipped, Delivered, Cancelled);
{$SCOPEDENUMS OFF}

// Usage: always fully qualified
var LStatus := TOrderStatus.Confirmed;
```

Forbidden:

```pascal
type
  TOrderStatus = (osCreated, osConfirmed, osShipped);  // unscoped + prefix
```

### 2.3 Form Design — Prefer DFM/FMX

Forms for VCL and FireMonkey applications MUST be designed via `.dfm` / `.fmx` files in the IDE designer. Manipulating form elements in source code is only permitted for **dynamic content** (e.g. variable-length lists, data-driven controls).

**Rationale:** Creating forms entirely in source bypasses the DFM/FMX scaling system and regularly causes layout and scaling problems under HighDPI.

## 3. Project Layout

```
<project>/
├── src/                        # Source (units, packages)
│   ├── <Project>.Engine.dpk    # Core package (RTL only, no UI deps)
│   ├── FMX/                    # FMX-specific units & package
│   └── VCL/                    # VCL-specific units & package
├── demo/                       # Demo apps
│   ├── FMX/
│   └── VCL/
├── tests/                      # DUnitX test project
├── build/                      # Build artifacts + build script
│   ├── DelphiBuildDPROJ.ps1
│   └── $(Platform)/$(Config)/
│       ├── *.exe, *.bpl
│       └── dcu/                # DCU + DCP
├── docs/                       # Style guide, documentation
├── libs/                       # External deps (Git submodules)
├── <Project>.groupproj         # Project group
├── .gitignore                  # Delphi-optimized
└── .gitattributes              # Delphi-optimized
```

Principles:
- **Core engine framework-agnostic** (RTL only) — usable from FMX and VCL
- **FMX/VCL as separate packages**
- **Dual-framework** (FMX + VCL) by default
- **Build output** lives exclusively under `/build/...`, never in the source tree
- **External deps** as Git submodules under `/libs`
- **One `.groupproj`** covers all packages, demos, tests

## 4. Git

Mandatory files in the project root (content from omonien/DelphiStandards):

| File | Source |
|---|---|
| `.gitignore` | [Delphi GitIgnore.txt](https://github.com/omonien/DelphiStandards/blob/master/Delphi%20GitIgnore.txt) |
| `.gitattributes` | [Delphi GitAttributes.txt](https://github.com/omonien/DelphiStandards/blob/master/Delphi%20GitAttributes.txt) |

Ensures: no DCU/EXE/temp files in the repo, CRLF normalization, correct text/binary handling.

## 5. Build & Output Paths (DPROJ)

Set in every `.dproj`:

| Path | Schema |
|---|---|
| Output (EXE/BPL) | `/build/$(platform)/$(config)` |
| DCU output | `/build/$(platform)/$(config)/dcu` |
| DCP output | `/build/$(platform)/$(config)/dcu` |

### 5.1 Exception: IDE-Loaded Packages

For design-time packages and their runtime deps loaded by the IDE:

| Output | Path |
|---|---|
| BPL | `$(BDSCOMMONDIR)\Bpl` |
| DCP | `$(BDSCOMMONDIR)\Dcp` |
| DCU | `/build/$(platform)/$(config)/dcu` (unchanged) |

Reason: `$(BDSCOMMONDIR)` is on the IDE search path automatically — no Library Path entry needed.

## 6. VersionInfo (DPROJ)

`IncludeVerInfo` MUST be `True`. VersionInfo MUST be set in both MSBuild PropertyGroups **and** BorlandProject sections.

### 6.1 Required Keys

| Key | Rule | Example |
|---|---|---|
| `CompanyName` | Default `Olaf Monien` | `Olaf Monien` |
| `FileDescription` | Module description | `DX.Scribe Code Editor Engine` |
| `FileVersion` | = `MajorVer.MinorVer.Release.Build` | `1.0.0.0` |
| `InternalName` | Project name without extension | `DX.Scribe.Engine` |
| `LegalCopyright` | Default `Copyright © <year> Olaf Monien` | `Copyright © 2026 Olaf Monien` |
| `LegalTrademarks` | empty (default) | |
| `OriginalFilename` | Output filename | `DX.Scribe.Engine.bpl` |
| `ProductName` | Product name | `DX.Scribe` |
| `ProductVersion` | Consistent across all packages | `1.0.0.0` |
| `Comments` | Optional, e.g. license | `MIT License` |

### 6.2 BorlandProject Block

```xml
<VersionInfo>
    <VersionInfo Name="IncludeVerInfo">True</VersionInfo>
    <VersionInfo Name="AutoIncBuild">False</VersionInfo>
    <VersionInfo Name="MajorVer">1</VersionInfo>
    <VersionInfo Name="MinorVer">0</VersionInfo>
    <VersionInfo Name="Release">0</VersionInfo>
    <VersionInfo Name="Build">0</VersionInfo>
    <VersionInfo Name="Debug">False</VersionInfo>
    <VersionInfo Name="PreRelease">False</VersionInfo>
    <VersionInfo Name="Special">False</VersionInfo>
    <VersionInfo Name="Private">False</VersionInfo>
    <VersionInfo Name="DLL">False</VersionInfo>
    <VersionInfo Name="Locale">1031</VersionInfo>
    <VersionInfo Name="CodePage">1252</VersionInfo>
</VersionInfo>
```

### 6.3 Rules

- Copyright default: `Olaf Monien` (override only with explicit user instruction)
- Version numbers consistent: `MajorVer.MinorVer.Release.Build` = `FileVersion` = `ProductVersion`
- `Locale` `1031` (German) as default, overridable per project
- `DLL`: `True` for `.bpl`, `False` for `.exe`
- New projects start at `1.0.0.0`

## 7. Unit Tests

- Framework: **DUnitX**
- Create only after user confirms (see `CLAUDE.md` "Ask at Project Start")
- Add DUnitX as a Git submodule

## 8. Unit Header (Mandatory)

Ask the user first: MIT license or other?

The header MUST appear directly before `unit <name>;`:

```pascal
/// <summary>
/// <unit-name>
/// <short-description>
/// </summary>
///
/// <remarks>
/// <detailed-description>
/// </remarks>
///
/// <copyright>
/// Copyright © <year> Olaf Monien
/// Licensed under MIT
/// </copyright>

unit <unit-name>;
```

| Placeholder | Meaning |
|---|---|
| `<unit-name>` | Fully qualified unit name |
| `<short-description>` | One-line summary |
| `<detailed-description>` | Multi-line explanation |
| `<year>` | Current year (4-digit) |

## 9. Build & Verification

After generating code, attempt to compile autonomously.

- Tool: `DelphiBuildDPROJ.ps1` from [omonien/DelphiStandards](https://github.com/omonien/DelphiStandards)
- Local placement: `/build/DelphiBuildDPROJ.ps1`
- The script auto-selects the newest installed Delphi version (typically Delphi 13)
- If a specific version is required: ask the user

## 10. Toolchain — Installation Paths

Delphi installs at `C:\Program Files (x86)\Embarcadero\Studio\<version>\`:

| Delphi | Version folder |
|---|---|
| 10.4 Sydney | `21.0` |
| 11 Alexandria | `22.0` |
| 12 Athens | `23.0` |
| 13 Florence | `37.0` |

`rsvars.bat` is at `<install>\bin\rsvars.bat`.

`DelphiBuildDPROJ.ps1` wraps `rsvars.bat` + `msbuild` — direct invocation is normally not needed.

## 11. Lines of Code — Counting Rule

When asked for the LOC of a Delphi project, report **application code** and **test code** separately, and report both **total LOC** (`wc -l`) and **effective LOC** (excluding blank lines and comments).

### Files counted

| Bucket | Files |
|---|---|
| Application | `src/**/*.pas`, `src/**/*.fmx`, `*.dpr` at project root |
| Tests | `tests/**/*.pas`, `tests/**/*.dpr` |

### Files NOT counted

- `.dproj` (MSBuild XML config — generated, not source)
- `.res`, `.dcu`, `.exe`, `.app` (binaries)
- `libs/**` (third-party / submodules — DUnitX, etc.)
- `build/**` (output dir, build scripts)
- `docs/**` (markdown, PRDs, plans)
- IDE local files (`*.local`, `*.dsk`, `__history/`, `__recovery/`)

### Effective-LOC stripper (bash awk)

Strips blank lines, `//` line comments, and `{ ... }` block comments (the standard XML doc header form). `(* ... *)` block comments aren't stripped — Delphi 12 codebases under these rules don't use them.

```bash
code_only() {
  awk '
    /^\s*$/ { next }
    /^\s*\/\// { next }
    /^\s*{[^$]/ { in_brace = 1 }
    in_brace && /}/ { in_brace = 0; next }
    in_brace { next }
    { print }
  ' "$1" | wc -l
}
```

### Standard report shape

Two tables (per-bucket totals + per-file breakdown), plus the **tests-to-app ratio** (effective LOC). A healthy ratio for a test-first project sits around 0.7–1.2:1; the Service test files typically dominate due to mocks + parametric coverage.
