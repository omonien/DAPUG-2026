# Project Coding Rules

Universal rules for all programming projects. Delphi-specific rules: see [`Delphi.md`](./Delphi.md) (canonical).

## Ask at Project Start (MUST)

Before starting work on a new project, the agent MUST clarify these points with the user:

1. **Project language** — English or German? Applies uniformly to code identifiers, comments, documentation, README, commit messages. Default for public/open-source projects: English.
2. **Tests** — Should unit tests be generated? If yes: required for new features and bugfixes; additionally integration/smoke tests when the framework allows.
3. **License (for code with header convention)** — MIT? See `Delphi.md` §8 for the header format.

## Universal Rules

### Clean Code
- **DRY** — no duplication of logic or code.
- **SoC** — clear separation of concerns.

### Comments
- Do not comment trivialities.
- Document classes and methods with XML doc comments (`/// <summary>`) — concise but clear.
- Comments should explain both the **what** (context, classification, important details) and the **why** (decisions, background, non-obvious logic).

### Language
- The project language chosen at start applies uniformly to **everything**: code identifiers, comments, documentation, commit messages.

### Tests (when enabled)
- New features: comprehensive unit tests
- Bugfixes: unit tests covering the bug
- When possible: integration/smoke tests

## Delphi (Quick Reference)

→ Full rules and rationale in [`Delphi.md`](./Delphi.md).

| Area | Rule |
|---|---|
| Encoding | `.pas` UTF-8 BOM · `.dfm`/`.fmx` `#<codepoint>` · CRLF everywhere |
| Naming | PascalCase · classes `T`, interfaces `I`, exceptions `E` · local `L`, fields `F`, parameters `A` · constants `c`/`sc`/`rs` |
| Enums | Scoped (`{$SCOPEDENUMS ON}`), no prefix |
| Form design | DFM/FMX designer · code-based creation only for dynamic content (HighDPI) |
| Project layout | `src/` `demo/` `tests/` `build/` `docs/` `libs/` |
| Output/DCU/DCP | `/build/$(platform)/$(config)[/dcu]` |
| IDE packages | Exception: BPL/DCP under `$(BDSCOMMONDIR)\Bpl` / `\Dcp` |
| Build tool | `DelphiBuildDPROJ.ps1` from `omonien/DelphiStandards`, placed in `/build` |
| VersionInfo | Mandatory in DPROJ · `IncludeVerInfo=True` · default copyright `Olaf Monien` · start at `1.0.0.0` |
| Unit header | XML doc with `<summary>`/`<remarks>`/`<copyright>` |
| Tests | DUnitX as Git submodule |

## Existing Projects — Caution

When the agent edits an existing project for the first time and finds deviations from the rule set (encoding, paths, naming, missing `.gitattributes`, etc.):

**Do NOT auto-correct.** Ask the user first: correct, or only document?
