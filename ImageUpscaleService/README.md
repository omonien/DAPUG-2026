# ImageUpscaleService

A small Delphi 13 web service that uploads an image and returns an
ultra-HD, cinematic remaster. The remaster is performed by Google's
**Nano Banana Pro** (`gemini-3-pro-image-preview`) using a fixed prompt
that preserves identity and composition while lifting technical quality.

Built with **Horse** (web framework), **HTMX** (client interactivity, no
custom JavaScript), and a tiny `@var` template substitution layer in lieu
of Web.Stencils. Created as a DAPUG 2026 workshop demo — see
[`docs/`](docs/) for the full PRD and implementation plan.

## Getting a Gemini API key

1. Go to **[Google AI Studio › API keys](https://aistudio.google.com/app/apikey)**
   and sign in with any Google account (no GCP project setup required for
   the free preview tier).
2. Click **Create API key** and either pick an existing Google Cloud
   project or accept the auto-created one.
3. Copy the key (starts with `AIza...`). Treat it like a password.
4. Copy `config.ini.example` to `config.ini` and paste the key as
   `[Gemini] ApiKey=AIza...`.
5. `config.ini` is in `.gitignore` — never commit it.

> **Pricing:** Nano Banana Pro (`gemini-3-pro-image-preview`) is in paid
> preview — see [Gemini API pricing](https://ai.google.dev/pricing). The
> free tier on a fresh project gives a small daily quota that is enough
> to demo a few images.

## Build

From the **repo root** (one level above `ImageUpscaleService/`):

```bash
git clone --recurse-submodules https://github.com/omonien/DAPUG-2026.git
cd DAPUG-2026
pwsh -File ImageUpscaleService/build/DelphiBuildDPROJ.ps1 \
  -ProjectFile ImageUpscaleService/ImageUpscaleService.dproj \
  -Platform Win64 -Config Debug
```

The build script auto-detects your installed Delphi version. No GetIt or
Boss install is needed — both **Horse** and **DelphiGemini** are vendored
as git submodules under `libs/`.

## Run

```bash
cd ImageUpscaleService
cp config.ini.example config.ini
# Edit config.ini, paste your Gemini API key into [Gemini] ApiKey=
build/Win64/Debug/ImageUpscaleService.exe
```

You should see:

```
Loaded remaster prompt, 787 chars
Project root:    C:\...\ImageUpscaleService\
Config:          C:\...\ImageUpscaleService\config.ini
Uploads / results: C:\...\var\uploads | C:\...\var\results
ImageUpscaleService listening on http://localhost:8080  (upscaler=native)
```

The exe finds `config.ini`, `templates/`, and `public/` by walking up
from its own location until it sees a `templates/` folder — so launching
from the repo root, from inside `build/Win64/Debug/`, or from the IDE all
work identically. Override the config path with `--config path\to\file.ini`
if you want to point somewhere else.

Open <http://localhost:8080/> in a browser, upload an image, pick a
resolution (1K / 2K / 4K), click **Upscale**.

## Two upscaler implementations

Set in `config.ini` under `[Upscaler] Provider=`:

- `native` — raw HTTPS via `TNetHTTPClient`, no third-party deps. Shows
  the bare wire format of the Gemini `generateContent` endpoint. Easiest
  to read for someone learning the API.
- `delphigemini` — community wrapper from
  [MaxiDonkey/DelphiGemini](https://github.com/MaxiDonkey/DelphiGemini)
  (vendored under `libs/DelphiGemini/`). Same call expressed in a few
  fluent-builder lines.

Both implement the same `IUpscaler` interface. Same prompt, same model,
same output. Compare them side by side as a teaching artifact.

## Run tests

```bash
pwsh -File ImageUpscaleService/build/DelphiBuildDPROJ.ps1 \
  -ProjectFile ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj \
  -Platform Win64 -Config Debug
echo "" | ImageUpscaleService/build/Win64/Debug/ImageUpscaleService.Tests.exe
```

42 tests: 41 pure unit tests + one integration smoke test that boots
Horse on port 18080 and exercises `GET /healthz` and `GET /` end-to-end.
**No live Gemini calls in tests** — every test uses `TFakeUpscaler`,
which returns a small canned PNG without touching the network.

## License

MIT — Copyright (c) 2026 Olaf Monien. See [`../LICENSE`](../LICENSE).
