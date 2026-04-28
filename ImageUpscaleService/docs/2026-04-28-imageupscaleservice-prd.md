# ImageUpscaleService — Product Requirements Document (PRD)

**Version:** 1.0 (design)
**Date:** 2026-04-28
**Author:** Olaf Monien
**Status:** Approved for implementation
**License:** MIT — Copyright (c) 2026 Olaf Monien
**Project language:** English (uniform across code, comments, docs, commits)

---

## 1. Purpose

`ImageUpscaleService` is a small Delphi web service that lets a user upload an
image through the browser and receive a remastered, ultra-high-definition
version of it. The remaster is performed by Google's **Nano Banana Pro**
(`gemini-3-pro-image-preview`) using a fixed, baked-in prompt focused on
preserving identity and composition while lifting technical quality.

The service serves two purposes:

1. **Utility** — a working "drop in an image, get back a cinematic remaster"
   tool runnable from a single executable on a workshop laptop.
2. **Workshop demo** — a teaching artifact for the DAPUG 2026 "Everything AI"
   workshop, showing modern Delphi web development with **Horse**,
   **WebStencils** server-side templating, **HTMX** for client interactivity
   without custom JavaScript, two interchangeable AI integration paths
   (raw HTTPS vs. a community wrapper), and DUnitX testing.

## 2. Target platform & toolchain

| Item             | Choice                                                  |
|------------------|---------------------------------------------------------|
| IDE / compiler   | Delphi 13 Florence                                      |
| Server framework | Horse (3rd-party microframework)                        |
| Templating       | WebStencils (Embarcadero, RTL)                          |
| Client framework | HTMX (no custom JS)                                     |
| AI model         | Nano Banana Pro — `gemini-3-pro-image-preview`          |
| AI access        | Two implementations behind `IUpscaler` (see §6)         |
| Targets          | `Win64` (primary), `Linux64` (secondary)                |
| Test framework   | DUnitX (Git submodule under `libs/DUnitX/`)             |
| Build tool       | `DelphiBuildDPROJ.ps1` from `omonien/DelphiStandards`   |
| Distribution     | Plain console `.exe` (Windows) / ELF binary (Linux)     |

## 3. User experience

### 3.1 Pages

| Page             | Path  | Description                                                  |
|------------------|-------|--------------------------------------------------------------|
| Upload form      | `/`   | Single-page form: file picker, three resolution radios (1K/2K/4K, default 2K), Upscale button |
| Job status       | (HTMX swap targets within `/`, polled via `GET /jobs/{id}`)  |
| Result view      | (HTMX swap target within `/`, before/after side-by-side)     |
| Error view       | (HTMX swap target within `/`)                                |

There is exactly **one** full HTML page. All other states are HTMX fragments
swapped into a single DOM hole inside that page. There are no menus, no
settings dialogs, no user accounts, and no history page.

### 3.2 Visual style

- Minimal CSS — system font stack, a centered card on a neutral background,
  one accent color for the Upscale button and links.
- No third-party CSS framework.
- The result view shows the original (left) and the remastered image (right)
  at equal width, plus a Download button, a "Try another" link, and a small
  caption *Remastered at NK* under the result image.

### 3.3 Interaction flow

1. User opens `/`, sees the form.
2. User selects a JPEG/PNG/WebP file (≤ 10 MB), picks an output resolution
   (1K/2K/4K, default 2K), and clicks **Upscale**.
3. Form submits via `hx-post="/upscale"`. Server validates, writes the file
   to disk, enqueues a job, and returns an HTML fragment that shows a spinner
   plus `hx-get="/jobs/{id}" hx-trigger="load delay:1s, every 1s"`.
4. HTMX polls `/jobs/{id}` once per second. While the job is `queued` or
   `running`, the same pending fragment is returned (poll continues).
5. When the job is `done`, the response is the result fragment (before/after
   + Download). It contains **no** `hx-trigger`, which stops the poll.
6. When the job is `error`, the response is the error fragment (also
   trigger-less, also stops the poll). It includes a "Try another" link that
   re-renders the form.

## 4. Functional requirements

### 4.1 Upload validation (in order, fail fast)

| Check                                                         | Failure response                                       | HTTP |
|---------------------------------------------------------------|--------------------------------------------------------|------|
| `Content-Length` ≤ 10 MB                                      | "File too large (max 10 MB)."                          | 413  |
| Multipart present, exactly one file field named `image`       | "No file selected."                                    | 422  |
| Declared MIME ∈ {`image/jpeg`, `image/png`, `image/webp`}     | "Unsupported format. Use JPEG, PNG, or WebP."          | 415  |
| Magic-bytes sniff matches the declared MIME                   | "File doesn't look like a real image."                 | 415  |
| `resolution` field ∈ {`1K`,`2K`,`4K`} (missing → default `2K`) | "Invalid resolution."                                  | 422  |
| Job queue depth < 20                                          | "Server busy. Try again in a moment."                  | 503  |

All error responses are rendered via the same `job_error.html` template so the
HTMX swap target stays consistent — same DOM hole, different content. HTTP
status codes are still set correctly so `curl` / DevTools see the right code.

### 4.2 Upscale prompt (verbatim, baked in)

The prompt is a single Pascal `const` in `IUS.Prompt.pas`. It MUST NOT be
templated, parameterized, or read from configuration:

```
Take the provided image and remaster it to pristine ultra-high-definition
cinematic quality. Every aspect of the original must remain completely intact -
the person's facial identity, expression, body posture, clothing, accessories,
environment, framing and overall composition stay exactly as they are. No
elements are changed, added or removed.
The upgrade is purely technical.
Reconstruct skin texture with natural visible pores and subtle real-world
detail. Define individual hair strands with precision.
Render the eyes sharp, clear and fully alive.
Clean and resolve every edge throughout the entire image.
Enhance the dynamic range, contrast and three-dimensional depth using balanced
studio-grade cinematic lighting that makes every surface feel physically
present and real.
```

Output resolution is selected by the user per request (1K / 2K / 4K, default
2K) — see §4.5.

### 4.3 Job state machine

```
                  POST /upscale
                       |
                       v
                  +---------+
                  | queued  |
                  +----+----+
                       |  worker picks up
                       v
                  +---------+
                  | running |
                  +----+----+
              +--------+--------+
              v                 v
         +---------+       +---------+
         |  done   |       |  error  |
         +---------+       +---------+
              |                 |
              +--------+--------+
                       v
              cleaned up after
              30 min by sweeper
```

States: `queued` → `running` → (`done` | `error`). All terminal states are
swept after the configured retention period (default 30 min) by a background
thread that runs every 5 min.

### 4.4 Concurrency

- **Worker pool:** 3 fixed worker threads consuming a FIFO queue.
- **Bounded queue:** depth limit 20. Over the limit → 503 (see §4.1).
- **No retries** on Gemini failures — surfaced honestly to the user. The
  workshop point is "see the failure" rather than "hide it".

### 4.5 Output resolution

Nano Banana Pro accepts an `imageSize` parameter on `generateContent` with
values `1K`, `2K`, or `4K`. The user picks one per request via three radio
buttons on the upload form (default `2K`). The selection is:

- validated server-side against the allowlist (see §4.1),
- stored on the `TJob` record as a `TUpscaleResolution` enum,
- passed to `IUpscaler.Upscale` (see §6),
- rendered as a caption under the result image (*Remastered at NK*).

Resolution choice does not change the prompt, the model, or any other
request parameter.

### 4.6 Upscaler error mapping

| Cause                                  | `TJob.ErrorMsg` shown to user                          |
|----------------------------------------|--------------------------------------------------------|
| Network / timeout (60 s cap)           | "Upscale service unreachable. Try again."              |
| Gemini 4xx (bad request, content filter) | "Image rejected by upscale service."                 |
| Gemini 429 (rate limit / quota)        | "Daily quota reached. Try again later."                |
| Gemini 5xx                             | "Upscale service temporarily unavailable."             |
| Response had no image part             | "Upscale service returned no image."                   |

Full server-side error details are logged to console; only the user-facing
message above is rendered to the browser.

## 5. HTTP routes

| Method & path        | Returns                              | Notes                                      |
|----------------------|--------------------------------------|--------------------------------------------|
| `GET /`              | Full page (`index.html`)             | Upload form                                |
| `POST /upscale`      | HTML fragment (`job_pending.html`)   | Validates upload, writes file, enqueues    |
| `GET /jobs/{id}`     | HTML fragment                        | Polled by HTMX; returns pending/done/error |
| `GET /original/{id}` | `image/jpeg|png|webp`                | Source bytes; 404 after retention expires  |
| `GET /result/{id}`   | `image/png`                          | Result bytes; 404 if not done or expired   |
| `GET /healthz`       | `200 OK` text "ok"                   | Liveness probe                             |
| Static `/static/*`   | `htmx.min.js`, `app.css`, favicon    | Served from `./public/`                    |

## 6. AI integration — two interchangeable implementations

Both implementations satisfy the same single-method interface. The active
implementation is selected at startup via `[Upscaler] Provider=` in
`config.ini` (see §8).

```pascal
TUpscaleResolution = (Res1K, Res2K, Res4K);

IUpscaler = interface
  ['{...GUID...}']
  /// Sends the source image bytes to the upscaler at the requested
  /// output resolution and returns the remastered image bytes. Raises
  /// EUpscalerError on any failure (the orchestrator maps the exception
  /// to a user-facing message).
  function Upscale(const ASource: TBytes;
                   const ASourceMime: string;
                   const AResolution: TUpscaleResolution): TBytes;
end;
```

### 6.1 Native implementation — `IUS.Upscaler.Native.pas`

- Uses `TNetHTTPClient` (RTL).
- Builds the JSON request body manually (`generateContent` schema), embeds the
  source image as base64 with `inlineData.mimeType`/`data`, sends the prompt
  text part, and sets `imageSize` to the requested resolution
  (`1K` / `2K` / `4K`).
- POSTs to:
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent`
  with the API key in the `x-goog-api-key` header.
- Parses the response JSON, finds the first `inlineData` part with a PNG MIME
  type, base64-decodes the bytes, and returns them.
- Maps HTTP status codes to specific `EUpscalerError` subclasses so the
  orchestrator can produce the right user-facing message.
- **Pedagogical purpose:** shows the wire format of the Gemini API in plain
  Delphi with no third-party dependencies — exactly what attendees can take
  back to their own projects.

### 6.2 DelphiGemini implementation — `IUS.Upscaler.DelphiGemini.pas`

- Wraps the `MaxiDonkey/DelphiGemini` library (MIT-licensed Delphi units,
  added as a Git submodule under `libs/DelphiGemini/`).
- The library is also installable from Embarcadero GetIt; for reproducibility
  we vendor it as a submodule.
- Uses the library's image-input + generateContent path with the same model
  string and prompt.
- **Pedagogical purpose:** shows how a thin community wrapper collapses the
  same call to a few lines, and lets attendees see what to look for when
  evaluating a third-party AI library for their own work.

### 6.3 Why this choice (not SmartCore / MakerAI)

- **MaxiDonkey/DelphiGemini** is Gemini-specific (no multi-provider
  abstraction noise), MIT, source-only, and works on Delphi 10.4+ — so
  attendees on older Delphi versions can still follow along.
- **SmartCore AI Components Pack** (bundled in RAD Studio 13+) and
  **MakerAI Suite** are multi-provider abstractions whose Gemini-specific
  behavior is not the focus of this demo and would obscure the teaching
  point.

## 7. Storage

- Both uploads and results live on disk, not in memory:
  - `./var/uploads/{jobid}.{ext}` — original bytes, original extension.
  - `./var/results/{jobid}.png` — remastered bytes (always PNG from Gemini).
- Job records (in-memory `TDictionary<TGUID, TJob>`) hold the paths plus a
  `CreatedAt` timestamp. Access is guarded by a `TCriticalSection`.
- A cleanup thread runs every 5 min and deletes any job whose `CreatedAt` is
  older than `[Storage] RetentionMinutes` (default 30), removing both the
  dictionary entry and the on-disk files.
- Process restart wipes the in-memory queue. Files left on disk from a prior
  run are also swept by the same predicate on next startup.

## 8. Configuration

All configuration lives in a single `config.ini` file (read once at startup
with `TIniFile`). The file is in `.gitignore`; a `config.ini.example` is
committed alongside it.

```ini
[Server]
Port=8080

[Gemini]
ApiKey=AIza-your-key-here
Model=gemini-3-pro-image-preview

[Upscaler]
; native | delphigemini
Provider=native

[Storage]
UploadDir=./var/uploads
ResultDir=./var/results
RetentionMinutes=30
```

CLI override: `--config path/to/other.ini` (useful for the workshop projector
vs. attendee laptops).

## 9. Startup self-check (fail fast, exit code != 0)

1. `config.ini` (or `--config` path) loads without error.
2. `[Gemini] ApiKey` is present and starts with `AIza`.
3. `[Upscaler] Provider` is `native` or `delphigemini`.
4. `[Storage] UploadDir` and `ResultDir` exist or can be created.
5. Listen port is available.
6. Print: `ImageUpscaleService listening on http://localhost:{port}  (upscaler={provider})`.

On any failure, print a one-line cause and a pointer to `config.ini.example`,
then exit non-zero.

## 10. Logging

- Console only (`Writeln`). No file logging, no structured framework.
- One line per HTTP request: method, path, status, elapsed ms.
- One line per job state transition:
  `job=<short-id> queued->running` etc.
- The remaster prompt is logged exactly once at startup
  (`Loaded remaster prompt, N chars`) so attendees can confirm it loaded.
- The API key is **never** logged.
- Full Gemini error responses are logged on failure; only the user-facing
  message from §4.6 is sent to the browser.

## 11. Project structure

```
ImageUpscaleService/
├── ImageUpscaleService.dproj / .dpr      # Horse console host, Win64 + Linux64
├── README.md                              # Includes "Getting a Gemini API key" (see §13)
├── config.ini.example                     # Template; real config.ini is gitignored
├── src/
│   ├── IUS.Config.pas                    # config.ini loader + TConfig record
│   ├── IUS.JobQueue.pas                  # TJob, TJobQueue, worker pool
│   ├── IUS.Storage.pas                   # disk read/write + cleanup sweep
│   ├── IUS.Upscaler.Intf.pas             # IUpscaler + EUpscalerError hierarchy
│   ├── IUS.Upscaler.Native.pas           # (a) raw HTTPS via TNetHTTPClient
│   ├── IUS.Upscaler.DelphiGemini.pas     # (b) MaxiDonkey/DelphiGemini wrapper
│   ├── IUS.Upscaler.Fake.pas             # test double (returns canned PNG)
│   ├── IUS.Validation.pas                # MIME + size + magic-byte checks
│   ├── IUS.Prompt.pas                    # the verbatim remaster prompt as a const
│   ├── IUS.Routes.pas                    # Horse route handlers
│   └── IUS.Server.pas                    # bootstrap: load config, wire WebStencils, start Horse
├── templates/                            # WebStencils .html
│   ├── layout.html                       # base shell
│   ├── index.html                        # upload form
│   ├── job_pending.html                  # spinner + queued/running fragment
│   ├── job_done.html                     # before/after + Download + Try another
│   └── job_error.html                    # error fragment
├── public/                               # static assets
│   ├── htmx.min.js
│   ├── app.css
│   └── favicon.ico
├── tests/                                # DUnitX
│   ├── ImageUpscaleService.Tests.dproj / .dpr
│   ├── IUS.Tests.Validation.pas
│   ├── IUS.Tests.Prompt.pas
│   ├── IUS.Tests.JobQueue.pas
│   ├── IUS.Tests.Storage.pas
│   └── IUS.Tests.Smoke.pas               # boots Horse on ephemeral port, GETs /
├── libs/
│   ├── DUnitX/                           # submodule
│   └── DelphiGemini/                     # submodule (MaxiDonkey)
├── build/
│   └── DelphiBuildDPROJ.ps1              # standard build script (omonien/DelphiStandards)
└── docs/
    └── 2026-04-28-imageupscaleservice-prd.md
```

## 12. Testing

- **Unit tests (DUnitX):**
  - `IUS.Validation` — size limit, MIME allowlist, magic-byte sniff for each
    accepted format and a representative wrong-format file, and resolution
    allowlist (each of `1K`/`2K`/`4K` accepted; missing → defaults to `2K`;
    invalid value → 422).
  - `IUS.Prompt` — exact byte-for-byte match against the canonical prompt
    text; guards against accidental edits.
  - `IUS.JobQueue` — enqueue, dequeue, status transitions, bounded-queue
    rejection at depth 20, concurrent enqueue from multiple threads,
    `Resolution` field round-trip on `TJob`.
  - `IUS.Storage` — sweep predicate (given a file age, should delete?),
    write/read round-trip.
- **Integration smoke test:**
  - Boots Horse on an ephemeral port using the **fake** upscaler.
  - Asserts `GET /` returns 200 with the upload form HTML.
  - Asserts `POST /upscale` with a tiny valid PNG returns the pending
    fragment, then polling `GET /jobs/{id}` eventually returns the done
    fragment with the canned result image accessible at `/result/{id}`.
- **No live Gemini calls in tests** — `IUpscaler` is always replaced with
  `IUS.Upscaler.Fake.pas` (returns a known PNG).

## 13. README content (to be created in the implementation phase)

The README MUST include a "Getting a Gemini API key" section containing:

> 1. Go to **[Google AI Studio › API keys](https://aistudio.google.com/app/apikey)**
>    and sign in with any Google account (no GCP project setup required for
>    the free preview tier).
> 2. Click **Create API key** and either pick an existing Google Cloud
>    project or accept the auto-created one.
> 3. Copy the key (starts with `AIza...`). Treat it like a password.
> 4. Copy `config.ini.example` to `config.ini` and paste the key as
>    `[Gemini] ApiKey=AIza...`.
> 5. `config.ini` is in `.gitignore` — never commit it.
>
> Pricing: Nano Banana Pro (`gemini-3-pro-image-preview`) is paid preview —
> see [Gemini API pricing](https://ai.google.dev/pricing). The free tier on
> a fresh project gives a small daily quota that is enough to demo a few
> images.

## 14. Out of scope

To prevent sprawl, the following are **explicitly out of scope** for v1:

- Authentication, user accounts, sessions
- Per-IP rate limiting, CSRF tokens
- HTTPS termination (use a reverse proxy or `ngrok` if needed)
- Persistent history / past-result gallery
- Image format conversion on input
- Cancellation of in-flight jobs
- Retries on Gemini failures
- Multiple prompts / preset selection
- Containerization (`Dockerfile`, compose) — may be added later as a
  separate phase if the workshop needs it
