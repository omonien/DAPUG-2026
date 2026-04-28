# Everything AI — DAPUG Delphi Workshop

<a href="https://www.dapug.dk/2026/02/workshop-everything-ai-with-olaf-monien.html">
  <img src="assets/olaf.png" alt="Workshop announcement — Olaf Monien" align="right" width="180" />
</a>

A 2-day workshop on using AI **with** Delphi (coding agents, prompt workflows, model selection) and putting AI **inside** Delphi applications (tool/function calling, document parsing, smart features). Hosted by [**DAPUG**](https://www.dapug.dk/) at Hotel Hesselet, Denmark.

→ Original [**workshop announcement on dapug.dk**](https://www.dapug.dk/2026/02/workshop-everything-ai-with-olaf-monien.html).

This repository is the public mirror of everything used and produced during the workshop: slides, agenda, conventions, prompts, code, and the Delphi project we build live with the room. It is organized so you can either review what we did or work through the same material on your own afterwards.

> **Status:** materials are being added as the workshop progresses. Expect this README and the contents below to be filled in over the two workshop days and finalized shortly after.

---

## Who this is for

You'll get value from this repository if you are:

- **A workshop attendee** — this is your reference for everything we covered and built together
- **A Delphi developer who didn't attend** — the materials are written to be self-contained so you can work through them at your own pace
- **A team lead evaluating AI tooling for Delphi** — the workflow artifacts and checklists are designed to be reusable in your team
- **Anyone curious how a small-but-real-world language community is adopting AI coding tools** — the agenda and notes give an honest view

By the end of the materials you'll have:

- A working mental model of the AI landscape relevant to Delphi developers (models, providers, agents, MCP, tooling)
- A real Delphi project built collaboratively with AI coding agents
- A **workflow kit** — prompt library, review checklist, repo conventions, model/tool selection matrix
- AI features integrated *inside* a Delphi application (smart search, document parsing, and attendee-driven ideas)

---

## Repository layout

```
DAPUG-2026/
├── Instructions/       # Agent rule files — the contract we hand to coding agents
│   ├── CLAUDE.md       #   Universal coding rules (Clean Code, comments, language, tests)
│   └── Delphi.md       #   Delphi-specific standards (encoding, naming, paths, headers, versioning)
├── DX.DateChanger/     # Live-coded demo: cross-platform FMX desktop tool (see below)
├── assets/             # Images and shared assets used in the README and slides
├── LICENSE             # MIT
├── .gitignore          # Delphi-optimised (binaries, IDE local files, build output)
└── .gitattributes      # UTF-8 BOM + CRLF rules for .pas / .dfm / .fmx
```

More material (slides, prompt library, workflow kit, in-app AI features) is added as the workshop progresses; folders show up here when their content is ready.

### `Instructions/` — agent rules

The two files in `Instructions/` are the rule set we hand every coding agent during the workshop. They are intentionally short and copy-paste-friendly so attendees can adapt them for their own Delphi repos.

- [`Instructions/CLAUDE.md`](Instructions/CLAUDE.md) — the **universal** rules: project-start questions (language, tests, license), DRY/SoC, comment policy, and a Delphi quick-reference table.
- [`Instructions/Delphi.md`](Instructions/Delphi.md) — the **canonical** Delphi standards: file encoding, naming conventions, scoped enums, project layout, build & output paths, version info, mandatory unit headers, and a section on counting LOC for Delphi projects.

These files are the same set of rules used to build the demo below, so reading them is the cleanest way to understand the conventions every commit follows.

### `DX.DateChanger/` — Day 1 live-build demo

A small but real Delphi 12 / FireMonkey desktop tool for **Windows and macOS**. Drag a file whose name starts with `YYYY-MM-DD` onto the window and the tool sets the file's creation, modification, and access timestamps to that date at 10:00 local time. Files that don't match are silently ignored. Minimalist GUI: one drop zone, one explanatory label, no menus.

It exists both as a useful utility *and* as a teaching artefact — every step of the build is preserved as PRD, plan, commits, and tests, so the full agentic-development workflow is reproducible end-to-end.

```
DX.DateChanger/
├── DX.DateChanger.dproj / .dpr      # Main FMX app (Win32 / Win64 / OSXARM64)
├── src/
│   ├── DX.DateChanger.Parser.pas    # Pure: filename → TDate (calendar-validated)
│   ├── DX.DateChanger.FileTime.pas  # IFileTimeSetter + Win32 + macOS impls ($IFDEF)
│   ├── DX.DateChanger.Service.pas   # Orchestrator: walks paths, delegates writes
│   └── FormMain.pas / .fmx          # Thin FMX shell — just wires drops to the service
├── tests/                           # DUnitX, 32 tests (parser + service + smoke)
├── libs/DUnitX/                     # Submodule (VSoftTechnologies/DUnitX)
├── build/DelphiBuildDPROJ.ps1       # Universal Delphi build script (omonien/DelphiStandards)
└── docs/
    ├── 2026-04-28-dx-datechanger-prd.md     # Full product requirements
    ├── 2026-04-28-dx-datechanger-plan.md    # Bite-sized TDD implementation plan
    └── Initial Idea.md                       # The original brief that started everything
```

Read the [PRD](DX.DateChanger/docs/2026-04-28-dx-datechanger-prd.md) for the design, the [implementation plan](DX.DateChanger/docs/2026-04-28-dx-datechanger-plan.md) for the task-by-task build order, and the Git log for how the agentic workflow actually unfolded.

---

## Following along on your own

You don't need to have attended to use this repo. To work through the hands-on parts yourself you'll want:

1. **Delphi toolchain** — RAD Studio (Delphi 12 Athens or 13 Florence recommended). [Community Edition](https://www.embarcadero.com/products/delphi/starter) is enough for the exercises.
2. **Git** — installed and on `PATH` (`git --version` works in your terminal)
3. **A Markdown editor** — VS Code, Notepad++, anything. Most of this repo is `.md`.
4. **A coding agent** — at least one of:
   - [Claude Code](https://claude.com/claude-code)
   - [Kilo Code](https://kilocode.ai)
   - [Cline](https://cline.bot/)
   - or another agent of your choice
5. **API access** — an API key for at least one cloud LLM (Anthropic, OpenAI, Google, Mistral). A local model via [Ollama](https://ollama.com) works as a backup.

Then:

```bash
git clone --recurse-submodules https://github.com/omonien/DAPUG-2026.git
cd DAPUG-2026
```

`--recurse-submodules` fetches DUnitX into `DX.DateChanger/libs/DUnitX/` so the demo's test project compiles. If you cloned without it, run `git submodule update --init` afterwards.

---

## How the repo is meant to be used

- **Markdown is the glue.** Slides, prompts, conventions, and AI handoffs all live as `.md`. If you want an agent to follow a rule, write it down here.
- **Agent rule files are contracts** between humans and coding agents — encoding, naming, build paths, headers. They are also good templates to copy into your own Delphi repos.
- **Prompts are first-class artifacts.** The prompts collected here are as important as the code they produced — that's where the leverage is.
- **Commits tell a story.** The Git history shows the sequence in which features were prompted, generated, reviewed, and fixed. Reading the log is itself a learning exercise.

---

## Questions, corrections, ideas

- **Issues / corrections** — open a GitHub issue on this repo
- **Workshop alumni** — pull requests welcome, especially for new prompts or improvements to the workflow kit
- **Hosting your own edition** — feel free to fork. The agenda and conventions are written to be adapted and reused.

---

## License

Released under the [MIT License](LICENSE) — both the code and the written materials. Copyright © 2026 Olaf Monien. Use, adapt, and reuse freely; attribution is appreciated but not required.

The repository ships with Delphi-optimized [`.gitignore`](.gitignore) and [`.gitattributes`](.gitattributes) (UTF-8 BOM + CRLF for `.pas`/`.dfm`/`.fmx`, ignoring build artifacts), taken from [omonien/DelphiStandards](https://github.com/omonien/DelphiStandards). Drop them into your own Delphi repos as a starting point.

