# Image description after upscale — design

**Date:** 2026-04-29
**Component:** `ImageUpscaleService`
**Status:** Approved (brainstorm)

## Goal

After an upscale job succeeds, automatically generate a short title and
caption that describe what is visible in the upscaled image, and show
them inline on the result page. The description loads asynchronously so
it never delays the moment the user sees the upscaled image.

## Decisions

| # | Question | Choice |
|---|---|---|
| 1 | Timing | Async two-phase — job goes `Done` as soon as upscale finishes; description streams in via a second HTMX poll. |
| 2 | Output shape | Title (2-5 word noun phrase) + caption (1-2 sentence prose). |
| 3 | Language | English only. Matches existing UI strings. |
| 4a | Model | `gemini-3.1-flash-lite-preview`. Configurable via `[Describer] Model=`. Reuses existing `[Gemini] ApiKey`. |
| 4b | Failure mode | Silent soft-fail. Log to console, hide the description block. The upscale result is unaffected. |
| Approach | Worker integration | Worker fans out: same upscale worker fire-and-forgets a `TThread` that runs the description after the job is set to `Done`. |

## Architecture overview

Three new Pascal units, four modified, one new route, two new template fragments, one modified template.

```
NEW   src/IUS.Describer.Intf.pas       IDescriber interface, TDescription record, EDescriber* exception tree
NEW   src/IUS.Describer.Native.pas     TNetHTTPClient implementation calling Gemini Flash with structured output
NEW   src/IUS.DescribePrompt.pas       Canonical describe prompt (mirrors IUS.Prompt.pas)
MOD   src/IUS.JobQueue.pas             TJob gains DescribeStatus/Title/Caption; worker spawns describe thread after Done
MOD   src/IUS.Config.pas               TConfig.DescribeModel; reads [Describer] Model=
MOD   src/IUS.Routes.pas               GET /describe/:id; render describe_pending / describe_done fragments
MOD   src/IUS.Server.pas               Construct TNativeDescriber, pass into StartWorkers
MOD   templates/job_done.html          Polling slot between compare grid and actions row
NEW   templates/describe_pending.html  "Analysing image…" with self-poll
NEW   templates/describe_done.html     Title + caption block
MOD   public/app.css                   Styles for .describe-slot / .describe-pending / .describe-done / .describe-title / .describe-caption / .describe-spinner
MOD   config.ini.example               [Describer] section
```

## Data shapes

### `IUS.Describer.Intf.pas`

```pascal
type
  TDescription = record
    Title:   string;  // 2-5 word noun phrase
    Caption: string;  // 1-2 sentences, plain prose
  end;

  EDescriberError            = class(Exception);
  EDescriberNetworkError     = class(EDescriberError);
  EDescriberRejectedError    = class(EDescriberError);
  EDescriberQuotaError       = class(EDescriberError);
  EDescriberServerError      = class(EDescriberError);
  EDescriberEmptyResultError = class(EDescriberError);

  IDescriber = interface
    ['{B7E1F4D2-2E8A-4B12-8C5C-9F4D8C2A1E33}']
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
  end;
```

The exception tree mirrors `EUpscalerError` so the workshop only has to
explain the pattern once.

### `TJob` extension (in `IUS.JobQueue.pas`)

```pascal
type
  TDescribeStatus = (NotRequested, Running, Done, Failed);

  TJob = record
    // ...existing fields...
    DescribeStatus:  TDescribeStatus;
    DescribeTitle:   string;
    DescribeCaption: string;
  end;
```

Three new `TJobQueue` methods, mirroring `SetResult` / `SetError`:

- `SetDescribeRunning(AId: TGuid)`
- `SetDescribeDone(AId: TGuid; const ATitle, ACaption: string)`
- `SetDescribeFailed(AId: TGuid)`

All three take the same critical section as the existing setters.
No `DescribeError` field is stored — failures are silent.

## Worker flow

In `TJobQueue.StartWorkers`, immediately after the existing `SetResult`:

```pascal
SetResult(LJob.Id, LResultPath);
Writeln(Format('job=%s running->done', [Copy(LJob.Id.ToString, 2, 8)]));

SetDescribeRunning(LJob.Id);
TThread.CreateAnonymousThread(
  procedure
  var LDesc: TDescription; LBytes: TBytes;
  begin
    try
      LBytes := IUS.Storage.ReadAllBytes(LResultPath);
      LDesc  := FDescriber.Describe(LBytes, 'image/png');
      SetDescribeDone(LJob.Id, LDesc.Title, LDesc.Caption);
    except
      on E: Exception do
      begin
        SetDescribeFailed(LJob.Id);
        Writeln(Format('job=%s describe failed: %s',
          [Copy(LJob.Id.ToString, 2, 8), E.Message]));
      end;
    end;
  end).Start;
```

The describe thread is `FreeOnTerminate := True` and is *not* tracked
in `FWorkers`. Lifecycle implications:

- `TJobQueue.StopWorkers` does **not** wait for in-flight describe
  threads. They reference `Self` only via the queue methods, which
  remain safe as long as the queue outlives them. In practice the
  service shuts down by exiting the process, so the orphan threads die
  with it.
- The describe thread reads the result PNG from disk, not from a
  captured `TBytes`, so it does not pin the upscale's working buffers.

`StartWorkers` gets a new parameter:

```pascal
procedure StartWorkers(const ACount: Integer;
                       const AUpscaler:  IUpscaler;
                       const ADescriber: IDescriber;
                       const AResultDir: string);
```

`FDescriber` is stored on the queue as a field next to `FUpscaler`.

## Describer implementation

### Prompt (`IUS.DescribePrompt.pas`)

```pascal
const
  cDescribePrompt =
    'You are looking at a single photographic image. Produce a JSON ' +
    'object with two fields:' + sLineBreak +
    '  title:   A 2-5 word noun phrase naming the dominant subject ' +
    'or scene.' + sLineBreak +
    '  caption: One or two sentences describing what is visible — ' +
    'subject, setting, mood, notable details. Plain prose, no lists, ' +
    'no markdown. Do not speculate beyond what is depicted.';
```

Guarded by a byte-exact unit test, same as `cRemasterPrompt`.

### Request body

```json
{
  "contents": [{
    "parts": [
      { "text": "<cDescribePrompt>" },
      { "inlineData": { "mimeType": "image/png", "data": "<base64>" } }
    ]
  }],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "object",
      "properties": {
        "title":   { "type": "string" },
        "caption": { "type": "string" }
      },
      "required": ["title", "caption"]
    }
  }
}
```

Using Gemini's structured-output (`responseSchema`) means the parser is
a one-liner instead of regex/heuristic prose chopping, and the prompt
no longer carries formatting instructions.

### Endpoint

`https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`

with `<model>` from `TConfig.DescribeModel`
(default `gemini-3.1-flash-lite-preview`).
API key passed in the `x-goog-api-key` header — same as the upscaler.

### Status code → exception mapping

| HTTP | Exception |
|---|---|
| 200 | parse JSON, extract `title` / `caption` |
| 429 | `EDescriberQuotaError` |
| 400 / 403 / 404 | `EDescriberRejectedError` |
| 500-599 | `EDescriberServerError` |
| network exception | `EDescriberNetworkError` |
| any other / missing fields | `EDescriberEmptyResultError` |

## Route

```pascal
THorse.Get('/describe/:id',
  procedure(Req: THorseRequest; Res: THorseResponse)
  var LId: TGuid; LJob: TJob;
  begin
    if not LSelf.TryParseJobId(Req.Params['id'], LId) then begin
      Res.Status(404).Send(''); Exit;
    end;
    if not LSelf.FQueue.TryGet(LId, LJob) then begin
      Res.Status(404).Send(''); Exit;
    end;
    case LJob.DescribeStatus of
      TDescribeStatus.NotRequested,
      TDescribeStatus.Running:    Res.Send(LSelf.RenderDescribePending(LJob));
      TDescribeStatus.Done:       Res.Send(LSelf.RenderDescribeDone(LJob));
      TDescribeStatus.Failed:     Res.Send('');
    end;
  end);
```

Helpers `RenderDescribePending(AJob)` and `RenderDescribeDone(AJob)`
follow the existing `RenderPending` / `RenderDone` pattern in
`IUS.Routes.pas`.

## Templates

### `templates/job_done.html` — addition

A polling slot is inserted between `.compare-grid` and `.actions-row`:

```html
<div class="describe-slot"
     hx-get="/describe/@jobId"
     hx-trigger="load delay:300ms"
     hx-swap="outerHTML">
</div>
```

The 300 ms delay keeps the slot from making a poll request before the
browser has rendered the result images.

### `templates/describe_pending.html` (new, fragment, no `@LayoutPage`)

```html
<div class="describe-slot describe-pending"
     hx-get="/describe/@jobId"
     hx-trigger="load delay:1s"
     hx-swap="outerHTML">
  <span class="describe-spinner"></span>
  <span>Analysing image&hellip;</span>
</div>
```

Self-polling lives inside the pending fragment, so polling stops
naturally when the swap-in delivers `describe_done.html` (or the empty
body of the failed branch).

### `templates/describe_done.html` (new, fragment)

```html
<div class="describe-slot describe-done">
  <h2 class="describe-title">@title</h2>
  <p class="describe-caption">@caption</p>
</div>
```

### Failed case

Empty response body. HTMX `outerHTML` swap with empty content removes
the polling div entirely — no visible failure, no leftover spinner.

## CSS

One new block in `public/app.css`, roughly 30 lines:

```css
.describe-slot { /* spacing + top border, separates from compare grid */ }
.describe-pending { /* flex row, muted text */ }
.describe-spinner { /* small spinner, reuse animation from existing pending state */ }
.describe-done { /* block layout */ }
.describe-title { /* accent colour, smaller than h1 */ }
.describe-caption { /* var(--text-secondary), normal weight */ }
```

## Config

`config.ini.example` gains:

```ini
[Describer]
Model=gemini-3.1-flash-lite-preview
```

`IUS.Config.LoadConfig` reads `[Describer] Model=` with the same
default. No new key validation needed; if the model string is wrong the
API call fails and the silent soft-fail kicks in.

## Server wiring

In `IUS.Server.pas`, after the upscaler is constructed:

```pascal
LDescriber := TNativeDescriber.Create(LConfig.ApiKey, LConfig.DescribeModel);
FQueue.StartWorkers(LWorkerCount, LUpscaler, LDescriber, LConfig.ResultDir);
```

## Tests

| Test unit | Coverage |
|---|---|
| `IUS.Tests.DescribePrompt.pas` *(new)* | Byte-exact assertion on `cDescribePrompt`, mirroring `IUS.Tests.Prompt`. Guards against accidental edits. |
| `IUS.Tests.Describer.Native.pas` *(new)* | `BuildRequestBody` produces JSON containing the prompt text, the inline base64 image with the right MIME, and the `responseSchema` block. `ExtractDescription` parses a captured fixture response into a `TDescription` correctly. Status-code → exception mapping (429→Quota, 5xx→Server, 400/403→Rejected, network→Network, missing parts→EmptyResult). |
| `IUS.Tests.JobQueue.pas` *(extend)* | New `TJob` fields default to `NotRequested` / empty. `SetDescribeRunning`, `SetDescribeDone`, `SetDescribeFailed` transition state under the same lock as the existing setters. |
| `IUS.Tests.Routes.pas` *(extend, if it exists)* | `/describe/:id` returns 404 for unknown IDs; renders the pending fragment for `NotRequested` / `Running`; renders the done fragment for `Done`; returns empty body for `Failed`. |

A `TFakeDescriber` (parallel to `TFakeUpscaler`) returns a canned
`TDescription` for any integration-style tests. No live API calls in
the test suite.

## Out of scope (YAGNI)

Explicitly not part of this work:

- German / multilingual descriptions
- Caching descriptions across re-uploads
- Showing the description on the pending page
- Letting users edit or regenerate the description
- Per-resolution prompt variants
- Token-streaming the description into the page
- A separate retention timer for descriptions (they live and die with the job record)
