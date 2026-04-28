# Instructions

This folder contains global Claude Code instruction files that are intended to be installed into the user's `.claude` configuration directory.

## Contents

- **`CLAUDE.md`** — Universal project coding rules (clean code, comments, language, tests) and a quick reference for Delphi conventions.
- **`Delphi.md`** — Canonical, in-depth Delphi coding standards (encoding, naming, project layout, build, packaging, version info, tests).

These files are **not** project-specific. They are reproduced here as part of the DAPUG 2026 workshop materials so participants can copy them into their own Claude Code setup.

## Installation

Copy both files into your user-level Claude Code configuration directory so Claude picks them up as global instructions for every project.

### Target location

| OS | Path |
|---|---|
| Windows | `%USERPROFILE%\.claude\` (e.g. `C:\Users\<you>\.claude\`) |
| macOS / Linux | `~/.claude/` |

### Steps

1. Create the `.claude` directory in your home folder if it does not already exist.
2. Copy `CLAUDE.md` and `Delphi.md` from this folder into `~/.claude/`.
3. Restart Claude Code (or start a new session) so the updated instructions are loaded.

### PowerShell (Windows)

```powershell
$dest = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path .\CLAUDE.md, .\Delphi.md -Destination $dest -Force
```

### Bash (macOS / Linux)

```bash
mkdir -p ~/.claude
cp CLAUDE.md Delphi.md ~/.claude/
```

## Notes

- If you already have a `~/.claude/CLAUDE.md`, **do not overwrite it blindly** — merge the rules manually so you keep your existing customizations.
- `CLAUDE.md` references `Delphi.md` via a relative link, so both files must live side-by-side in the same directory.
- These instructions apply globally to all projects opened with Claude Code. Per-project overrides belong in a project-local `CLAUDE.md` at the repository root.
