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

Workshop content lives under dated edition folders. The folder name reflects the year and month of the edition; future editions will sit alongside in their own folders.

```
2026-04/    # this edition
```

Inside each edition folder you can expect to find:

- **Agenda and slides** — the schedule and presentation material
- **Conventions** — Delphi project, build, and Git rules used throughout
- **Agent rules** — the instruction files we hand to coding agents (Clean Code, naming, headers, build paths, version info)
- **The shared project** — the Delphi codebase built live during the hands-on blocks
- **Prompt library** — reusable prompt templates collected during the workshop
- **Workflow kit** — review checklists, AI safety rules, repo conventions, model/tool selection matrix
- **AI features** — the in-app AI features built on Day 2
- **Production checklist** — security, latency, cost, observability, testing, and rollout notes

A detailed index of files will be added here once the workshop wraps up.

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
git clone https://github.com/omonien/DAPUG-2026.git
cd DAPUG-2026
```

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

