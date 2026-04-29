# Image Description After Upscale — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After an upscale job succeeds, asynchronously generate a short title + 1-2 sentence caption describing the upscaled image (via Gemini 3.1 Flash-Lite) and stream it into the result page via HTMX, with silent soft-fail on description errors.

**Architecture:** New `IDescriber` interface (parallel to `IUpscaler`) called by a fire-and-forget `TThread` spawned by the upscale worker after the job is set to `Done`. Description state lives on `TJob` (status + title + caption). HTMX polls `GET /describe/:id` from inside `job_done.html` and self-replaces with either the title/caption block, an "analysing…" spinner, or empty markup on failure. Tests use a `TFakeDescriber`; no live API calls in the suite.

**Tech Stack:** Delphi 12 (Object Pascal), Horse, Web.Stencils, TNetHTTPClient, System.JSON, DUnitX, HTMX.

**Spec reference:** `docs/superpowers/specs/2026-04-29-image-description-design.md`

---

## File Structure

| File | Status | Purpose |
|---|---|---|
| `ImageUpscaleService/src/IUS.Describer.Intf.pas` | NEW | Interface, `TDescription` record, `EDescriber*` exception tree |
| `ImageUpscaleService/src/IUS.DescribePrompt.pas` | NEW | Canonical describe prompt constant |
| `ImageUpscaleService/src/IUS.Describer.Fake.pas` | NEW | Test double returning a canned `TDescription` |
| `ImageUpscaleService/src/IUS.Describer.Native.pas` | NEW | `TNetHTTPClient`-based Gemini Flash implementation |
| `ImageUpscaleService/src/IUS.JobQueue.pas` | MOD | `TJob` adds `DescribeStatus/Title/Caption`; new setters; worker spawns describe thread |
| `ImageUpscaleService/src/IUS.Config.pas` | MOD | `TConfig.DescribeModel` reads `[Describer] Model=` |
| `ImageUpscaleService/src/IUS.Routes.pas` | MOD | New `GET /describe/:id`; `RenderDescribePending` / `RenderDescribeDone` helpers |
| `ImageUpscaleService/src/IUS.Server.pas` | MOD | Construct `TNativeDescriber`; pass to `StartWorkers` |
| `ImageUpscaleService/templates/job_done.html` | MOD | Polling slot between compare grid and actions |
| `ImageUpscaleService/templates/describe_pending.html` | NEW | "Analysing image…" fragment with self-poll |
| `ImageUpscaleService/templates/describe_done.html` | NEW | Title + caption fragment |
| `ImageUpscaleService/public/app.css` | MOD | `.describe-*` block (~30 lines) |
| `ImageUpscaleService/config.ini.example` | MOD | New `[Describer]` section |
| `ImageUpscaleService/ImageUpscaleService.dpr` | MOD | Register the four new units |
| `ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj` | MOD | Register new src and test units |
| `ImageUpscaleService/tests/IUS.Tests.DescribePrompt.pas` | NEW | Byte-exact prompt test |
| `ImageUpscaleService/tests/IUS.Tests.Describer.Fake.pas` | NEW | Fake describer behaviour test |
| `ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas` | NEW | Build/parse/error mapping tests for native describer |
| `ImageUpscaleService/tests/IUS.Tests.JobQueue.pas` | MOD | Tests for new describe setters + worker fan-out |

---

## Conventions

- All new `.pas` files: **UTF-8 with BOM**, **CRLF** line endings (Delphi standard, see `Delphi.md`).
- Identifier naming: `T`/`I`/`E` prefixes; locals `L`-prefix; fields `F`-prefix; parameters `A`-prefix; constants `c`-prefix; scoped enums (`{$SCOPEDENUMS ON}`).
- Comments and code in **English** (matches existing project).
- License header: same XML-doc block as existing units, with `Copyright (c) 2026 Olaf Monien. MIT License.`.
- Tests: DUnitX `[TestFixture]` + `[Test]` attributes, `initialization` block calling `TDUnitX.RegisterTestFixture`.

**Build/test commands** (run from `ImageUpscaleService/tests/`):
```bash
# Build the test exe (workshop convention)
"C:/Program Files (x86)/Embarcadero/Studio/23.0/bin/MSBuild.exe" ImageUpscaleService.Tests.dproj //p:Config=Debug //p:Platform=Win64
# Run the tests
./build/Win64/Debug/ImageUpscaleService.Tests.exe
```

If the engineer cannot run MSBuild locally, they should still write all code and tests; the user will compile in the IDE.

---

## Task 1: `IUS.Describer.Intf` — interface unit

**Files:**
- Create: `ImageUpscaleService/src/IUS.Describer.Intf.pas`
- Modify: `ImageUpscaleService/ImageUpscaleService.dpr` (register the new unit)

- [ ] **Step 1.1: Create `IUS.Describer.Intf.pas`**

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Single-method interface that hides whether description is done via
  ///   raw HTTPS or a test fake.
  /// </summary>
  /// <remarks>
  ///   Mirrors the IUpscaler pattern. Exception tree maps onto the same
  ///   HTTP status code shape (network / rejected / quota / server / empty).
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Intf;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  /// <summary>Title (2-5 word noun phrase) plus 1-2 sentence caption.</summary>
  TDescription = record
    Title:   string;
    Caption: string;
  end;

  /// <summary>Base class for any describer failure surfaced to the worker.</summary>
  EDescriberError            = class(Exception);
  EDescriberNetworkError     = class(EDescriberError);
  EDescriberRejectedError    = class(EDescriberError);
  EDescriberQuotaError       = class(EDescriberError);
  EDescriberServerError      = class(EDescriberError);
  EDescriberEmptyResultError = class(EDescriberError);

  IDescriber = interface
    ['{B7E1F4D2-2E8A-4B12-8C5C-9F4D8C2A1E33}']
    /// <summary>Sends AImage (with declared AImageMime) to the Flash model
    ///   and returns the parsed TDescription. Raises an EDescriberError
    ///   subclass on any failure.</summary>
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
  end;

implementation

end.
```

- [ ] **Step 1.2: Register in `ImageUpscaleService.dpr`**

Insert one line after `IUS.Upscaler.DelphiGemini in '...';`, before the final `;`:

```pascal
program ImageUpscaleService;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  IUS.Server in 'src\IUS.Server.pas',
  IUS.Config in 'src\IUS.Config.pas',
  IUS.JobQueue in 'src\IUS.JobQueue.pas',
  IUS.Storage in 'src\IUS.Storage.pas',
  IUS.Routes in 'src\IUS.Routes.pas',
  IUS.Validation in 'src\IUS.Validation.pas',
  IUS.Prompt in 'src\IUS.Prompt.pas',
  IUS.Upscaler.Intf in 'src\IUS.Upscaler.Intf.pas',
  IUS.Upscaler.Fake in 'src\IUS.Upscaler.Fake.pas',
  IUS.Upscaler.Native in 'src\IUS.Upscaler.Native.pas',
  IUS.Upscaler.DelphiGemini in 'src\IUS.Upscaler.DelphiGemini.pas',
  IUS.Describer.Intf in 'src\IUS.Describer.Intf.pas';
```

(Subsequent tasks add the other three describer units to this `uses` clause.)

- [ ] **Step 1.3: Commit**

```bash
git add ImageUpscaleService/src/IUS.Describer.Intf.pas ImageUpscaleService/ImageUpscaleService.dpr
git commit -m "feat(imageupscaleservice): add IDescriber interface and exception tree"
```

---

## Task 2: `IUS.DescribePrompt` — canonical prompt + byte-exact test

**Files:**
- Create: `ImageUpscaleService/src/IUS.DescribePrompt.pas`
- Create: `ImageUpscaleService/tests/IUS.Tests.DescribePrompt.pas`
- Modify: `ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj` (register both)
- Modify: `ImageUpscaleService/ImageUpscaleService.dpr` (register the prompt unit)

- [ ] **Step 2.1: Write the failing test**

Create `ImageUpscaleService/tests/IUS.Tests.DescribePrompt.pas`:

```pascal
unit IUS.Tests.DescribePrompt;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TDescribePromptTests = class
  public
    [Test]
    procedure Prompt_MatchesCanonicalText_ByteExact;
    [Test]
    procedure Prompt_LengthIsNonZero;
  end;

implementation

uses
  System.SysUtils,
  IUS.DescribePrompt;

const
  cExpectedPrompt =
    'You are looking at a single photographic image. Produce a JSON ' +
    'object with two fields:' + sLineBreak +
    '  title:   A 2-5 word noun phrase naming the dominant subject ' +
    'or scene.' + sLineBreak +
    '  caption: One or two sentences describing what is visible - ' +
    'subject, setting, mood, notable details. Plain prose, no lists, ' +
    'no markdown. Do not speculate beyond what is depicted.';

procedure TDescribePromptTests.Prompt_MatchesCanonicalText_ByteExact;
begin
  Assert.AreEqual(cExpectedPrompt, IUS.DescribePrompt.cDescribePrompt,
    'Describe prompt has drifted from the canonical text. ' +
    'If the change is intentional, update both the unit and this test.');
end;

procedure TDescribePromptTests.Prompt_LengthIsNonZero;
begin
  Assert.IsTrue(Length(IUS.DescribePrompt.cDescribePrompt) > 0, 'Prompt is empty');
end;

initialization
  TDUnitX.RegisterTestFixture(TDescribePromptTests);

end.
```

> Note: the em-dash in "subject - setting" uses an ASCII `-` (not Unicode). Keep it that way to avoid encoding issues in the byte-exact comparison.

- [ ] **Step 2.2: Verify it fails**

The test will fail to compile because `IUS.DescribePrompt` doesn't exist yet. That's the failure we want at this step.

- [ ] **Step 2.3: Create the prompt unit**

Create `ImageUpscaleService/src/IUS.DescribePrompt.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Canonical describe prompt sent to Gemini Flash for every successful
  ///   upscale job, instructing the model to return a JSON title + caption.
  /// </summary>
  /// <remarks>
  ///   The text is intentionally fixed: the demo's whole behavior is shaped
  ///   by these instructions. Changing this string changes the output of
  ///   every future description - guarded by a byte-exact unit test in
  ///   IUS.Tests.DescribePrompt.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.DescribePrompt;

interface

uses
  System.SysUtils;

const
  /// <summary>Verbatim text sent as the prompt part of every describe call.</summary>
  cDescribePrompt =
    'You are looking at a single photographic image. Produce a JSON ' +
    'object with two fields:' + sLineBreak +
    '  title:   A 2-5 word noun phrase naming the dominant subject ' +
    'or scene.' + sLineBreak +
    '  caption: One or two sentences describing what is visible - ' +
    'subject, setting, mood, notable details. Plain prose, no lists, ' +
    'no markdown. Do not speculate beyond what is depicted.';

implementation

end.
```

- [ ] **Step 2.4: Register in `ImageUpscaleService.dpr`**

Add one line after `IUS.Describer.Intf in 'src\IUS.Describer.Intf.pas',`:

```pascal
  IUS.Describer.Intf in 'src\IUS.Describer.Intf.pas',
  IUS.DescribePrompt in 'src\IUS.DescribePrompt.pas';
```

- [ ] **Step 2.5: Register in `ImageUpscaleService.Tests.dproj`**

Open `ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj`. Find the `<DCCReference Include="..\src\IUS.Prompt.pas"/>` line and add **two new lines** after the line `<DCCReference Include="IUS.Tests.Smoke.pas"/>` (line ~101 in the file, end of the existing test list, just before `</ItemGroup>`):

```xml
        <DCCReference Include="..\src\IUS.DescribePrompt.pas"/>
        <DCCReference Include="IUS.Tests.DescribePrompt.pas"/>
```

(More references to this dproj are added in later tasks. Always add new entries before `</ItemGroup>`.)

- [ ] **Step 2.6: Run tests, verify pass**

Build and run:
```bash
cd ImageUpscaleService/tests
"C:/Program Files (x86)/Embarcadero/Studio/23.0/bin/MSBuild.exe" ImageUpscaleService.Tests.dproj //p:Config=Debug //p:Platform=Win64
./build/Win64/Debug/ImageUpscaleService.Tests.exe
```

Expected: `TDescribePromptTests` shows 2 tests, both passing. All previously passing tests still pass.

If the engineer cannot run MSBuild, they should at least check that the test source compiles in the Delphi IDE.

- [ ] **Step 2.7: Commit**

```bash
git add ImageUpscaleService/src/IUS.DescribePrompt.pas \
        ImageUpscaleService/tests/IUS.Tests.DescribePrompt.pas \
        ImageUpscaleService/ImageUpscaleService.dpr \
        ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj
git commit -m "feat(imageupscaleservice): add canonical describe prompt with byte-exact test"
```

---

## Task 3: `IUS.Describer.Fake` — test double + tests

**Files:**
- Create: `ImageUpscaleService/src/IUS.Describer.Fake.pas`
- Create: `ImageUpscaleService/tests/IUS.Tests.Describer.Fake.pas`
- Modify: `ImageUpscaleService/ImageUpscaleService.dpr`
- Modify: `ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj`

- [ ] **Step 3.1: Write the failing test**

Create `ImageUpscaleService/tests/IUS.Tests.Describer.Fake.pas`:

```pascal
unit IUS.Tests.Describer.Fake;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFakeDescriberTests = class
  public
    [Test] procedure Returns_NonEmptyTitleAndCaption;
    [Test] procedure CallCount_IncrementsPerCall;
    [Test] procedure RaiseOnNextCall_FlipsToConfiguredException;
  end;

implementation

uses
  System.SysUtils,
  IUS.Describer.Intf,
  IUS.Describer.Fake;

procedure TFakeDescriberTests.Returns_NonEmptyTitleAndCaption;
var
  LFake: IDescriber;
  LDesc: TDescription;
begin
  LFake := TFakeDescriber.Create;
  LDesc := LFake.Describe(TBytes.Create(1, 2, 3), 'image/png');
  Assert.IsTrue(Length(LDesc.Title) > 0);
  Assert.IsTrue(Length(LDesc.Caption) > 0);
end;

procedure TFakeDescriberTests.CallCount_IncrementsPerCall;
var
  LFake: TFakeDescriber;
  LIntf: IDescriber;
begin
  LFake := TFakeDescriber.Create;
  LIntf := LFake;
  Assert.AreEqual(0, LFake.CallCount);
  LIntf.Describe(TBytes.Create(1), 'image/png');
  LIntf.Describe(TBytes.Create(1), 'image/png');
  Assert.AreEqual(2, LFake.CallCount);
end;

procedure TFakeDescriberTests.RaiseOnNextCall_FlipsToConfiguredException;
var
  LFake: TFakeDescriber;
  LIntf: IDescriber;
begin
  LFake := TFakeDescriber.Create;
  LIntf := LFake;
  LFake.RaiseOnNextCall(EDescriberQuotaError);
  Assert.WillRaise(
    procedure begin LIntf.Describe(TBytes.Create(1), 'image/png'); end,
    EDescriberQuotaError);
end;

initialization
  TDUnitX.RegisterTestFixture(TFakeDescriberTests);

end.
```

- [ ] **Step 3.2: Verify it fails**

Compile error: `IUS.Describer.Fake` doesn't exist yet.

- [ ] **Step 3.3: Create the fake**

Create `ImageUpscaleService/src/IUS.Describer.Fake.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Test double for IDescriber. Returns a canned TDescription and counts
  ///   calls. Can be configured to raise a specific EDescriber* on the next
  ///   call to exercise the worker's silent-failure path.
  /// </summary>
  /// <remarks>
  ///   Used by every unit test and the integration smoke test. Never makes
  ///   network calls.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Fake;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  IUS.Describer.Intf;

type
  TFakeDescriber = class(TInterfacedObject, IDescriber)
  strict private
    FCallCount: Integer;
    FLock: TCriticalSection;
    FNextException: ExceptClass;
  public
    constructor Create;
    destructor Destroy; override;
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
    /// <summary>Configures the fake so the next Describe call raises
    ///   AException with a fixed message. Cleared after one use.</summary>
    procedure RaiseOnNextCall(const AException: ExceptClass);
    property CallCount: Integer read FCallCount;
  end;

implementation

constructor TFakeDescriber.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TFakeDescriber.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TFakeDescriber.Describe(const AImage: TBytes; const AImageMime: string): TDescription;
var
  LToRaise: ExceptClass;
begin
  FLock.Enter;
  try
    Inc(FCallCount);
    LToRaise := FNextException;
    FNextException := nil;
  finally
    FLock.Leave;
  end;
  if LToRaise <> nil then
    raise LToRaise.Create('fake error');
  Result.Title   := 'Test scene';
  Result.Caption := 'A canned caption returned by the fake describer for unit tests.';
end;

procedure TFakeDescriber.RaiseOnNextCall(const AException: ExceptClass);
begin
  FLock.Enter;
  try
    FNextException := AException;
  finally
    FLock.Leave;
  end;
end;

end.
```

- [ ] **Step 3.4: Register in `ImageUpscaleService.dpr`**

Add one line after `IUS.DescribePrompt in 'src\IUS.DescribePrompt.pas',`:

```pascal
  IUS.DescribePrompt in 'src\IUS.DescribePrompt.pas',
  IUS.Describer.Fake in 'src\IUS.Describer.Fake.pas';
```

- [ ] **Step 3.5: Register in `ImageUpscaleService.Tests.dproj`**

Add two more `<DCCReference>` entries inside the same `<ItemGroup>`, after the previously-added DescribePrompt lines:

```xml
        <DCCReference Include="..\src\IUS.Describer.Intf.pas"/>
        <DCCReference Include="..\src\IUS.Describer.Fake.pas"/>
        <DCCReference Include="IUS.Tests.Describer.Fake.pas"/>
```

(`IUS.Describer.Intf.pas` is registered here once and reused by every following describer task — do not duplicate it later.)

- [ ] **Step 3.6: Run tests, verify pass**

Run the test suite. Expected: `TFakeDescriberTests` reports 3 passing tests; all other tests still pass.

- [ ] **Step 3.7: Commit**

```bash
git add ImageUpscaleService/src/IUS.Describer.Fake.pas \
        ImageUpscaleService/tests/IUS.Tests.Describer.Fake.pas \
        ImageUpscaleService/ImageUpscaleService.dpr \
        ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj
git commit -m "feat(imageupscaleservice): add TFakeDescriber test double"
```

---

## Task 4: `IUS.Describer.Native` — request body builder (TDD)

**Files:**
- Create: `ImageUpscaleService/src/IUS.Describer.Native.pas`
- Create: `ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas`
- Modify: `ImageUpscaleService/ImageUpscaleService.dpr`
- Modify: `ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj`

This task only covers `BuildRequestBody`. Parsing is in Task 5; HTTP handling is in Task 6.

- [ ] **Step 4.1: Write the failing test**

Create `ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas`:

```pascal
unit IUS.Tests.Describer.Native;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNativeDescriberTests = class
  public
    [Test] procedure BuildRequestBody_ContainsPromptText;
    [Test] procedure BuildRequestBody_ContainsInlineDataWithMime;
    [Test] procedure BuildRequestBody_ContainsResponseSchema;
    [Test] procedure BuildRequestBody_Base64IsUnbroken;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  System.JSON,
  IUS.Describer.Native,
  IUS.DescribePrompt;

function MakeDescriber: TNativeDescriber;
begin
  Result := TNativeDescriber.Create('AIza-test-key', 'gemini-3.1-flash-lite-preview');
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsPromptText;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, 'You are looking at a single photographic image');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsInlineDataWithMime;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, '"inlineData"');
    Assert.Contains(LBody, '"mimeType":"image\/png"');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_ContainsResponseSchema;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(TBytes.Create(1, 2, 3), 'image/png');
    Assert.Contains(LBody, '"responseMimeType":"application\/json"');
    Assert.Contains(LBody, '"responseSchema"');
    Assert.Contains(LBody, '"title"');
    Assert.Contains(LBody, '"caption"');
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.BuildRequestBody_Base64IsUnbroken;
var
  LDescriber: TNativeDescriber;
  LBody: string;
begin
  // Use 100 bytes - long enough that wrap-style base64 would insert a newline.
  LDescriber := MakeDescriber;
  try
    LBody := LDescriber.BuildRequestBody(
      TEncoding.ASCII.GetBytes(StringOfChar('X', 100)), 'image/png');
    Assert.IsFalse(LBody.Contains(#13), 'Body must not contain CR');
    Assert.IsFalse(LBody.Contains(#10), 'Body must not contain LF');
  finally
    LDescriber.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNativeDescriberTests);

end.
```

- [ ] **Step 4.2: Verify it fails**

Compile error: `IUS.Describer.Native` doesn't exist.

- [ ] **Step 4.3: Implement `TNativeDescriber.BuildRequestBody`**

Create `ImageUpscaleService/src/IUS.Describer.Native.pas`:

```pascal
{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IDescriber implementation using TNetHTTPClient + System.JSON to call
  ///   Gemini Flash's generateContent endpoint with structured-output.
  /// </summary>
  /// <remarks>
  ///   Pedagogical: built side-by-side with TNativeUpscaler so the workshop
  ///   can compare. Same wire shape, different generationConfig - this one
  ///   asks for application/json with a fixed responseSchema (title + caption)
  ///   so parsing is a one-liner instead of regex over prose.
  /// </remarks>
  /// <copyright>Copyright (c) 2026 Olaf Monien. MIT License.</copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Native;

interface

uses
  System.SysUtils, System.Classes, System.NetEncoding, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  IUS.Describer.Intf;

type
  TNativeDescriber = class(TInterfacedObject, IDescriber)
  strict private
    FApiKey: string;
    FModel: string;
  public
    constructor Create(const AApiKey, AModel: string);
    /// <summary>Builds the JSON request body. Public so unit tests can inspect
    ///   the wire format without going through the HTTP layer.</summary>
    function BuildRequestBody(const AImage: TBytes; const AImageMime: string): string;
    /// <summary>Parses a Gemini structured-output response into a TDescription.
    ///   Public for unit-test purposes.</summary>
    function ExtractDescription(const AResponseBody: string): TDescription;
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
  end;

implementation

uses
  IUS.DescribePrompt;

constructor TNativeDescriber.Create(const AApiKey, AModel: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel  := AModel;
end;

function TNativeDescriber.BuildRequestBody(const AImage: TBytes;
                                           const AImageMime: string): string;
var
  LRoot, LContent, LTextPart, LImagePart, LInlineData, LGenCfg, LSchema,
  LProps, LTitleProp, LCaptionProp: TJSONObject;
  LContents, LParts, LRequired: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LContents := TJSONArray.Create;
    LContent  := TJSONObject.Create;
    LParts    := TJSONArray.Create;

    LTextPart := TJSONObject.Create;
    LTextPart.AddPair('text', cDescribePrompt);
    LParts.AddElement(LTextPart);

    LInlineData := TJSONObject.Create;
    LInlineData.AddPair('mimeType', AImageMime);
    // Base64String (not Base64) is the unbroken-line variant. The Gemini API
    // rejects RFC 2045-style 76-char line wrapping with "Base64 decoding failed".
    LInlineData.AddPair('data',
      TNetEncoding.Base64String.EncodeBytesToString(AImage));
    LImagePart := TJSONObject.Create;
    LImagePart.AddPair('inlineData', LInlineData);
    LParts.AddElement(LImagePart);

    LContent.AddPair('parts', LParts);
    LContents.AddElement(LContent);
    LRoot.AddPair('contents', LContents);

    // Structured output: ask for JSON conforming to a fixed schema.
    LTitleProp   := TJSONObject.Create;
    LTitleProp.AddPair('type', 'string');
    LCaptionProp := TJSONObject.Create;
    LCaptionProp.AddPair('type', 'string');

    LProps := TJSONObject.Create;
    LProps.AddPair('title', LTitleProp);
    LProps.AddPair('caption', LCaptionProp);

    LRequired := TJSONArray.Create;
    LRequired.Add('title');
    LRequired.Add('caption');

    LSchema := TJSONObject.Create;
    LSchema.AddPair('type', 'object');
    LSchema.AddPair('properties', LProps);
    LSchema.AddPair('required', LRequired);

    LGenCfg := TJSONObject.Create;
    LGenCfg.AddPair('responseMimeType', 'application/json');
    LGenCfg.AddPair('responseSchema', LSchema);
    LRoot.AddPair('generationConfig', LGenCfg);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TNativeDescriber.ExtractDescription(const AResponseBody: string): TDescription;
begin
  // Implemented in Task 5.
  raise EDescriberEmptyResultError.Create('not implemented yet');
end;

function TNativeDescriber.Describe(const AImage: TBytes;
                                   const AImageMime: string): TDescription;
begin
  // Implemented in Task 6.
  raise EDescriberNetworkError.Create('not implemented yet');
end;

end.
```

- [ ] **Step 4.4: Register in `ImageUpscaleService.dpr`**

Add one line after `IUS.Describer.Fake in 'src\IUS.Describer.Fake.pas',`:

```pascal
  IUS.Describer.Fake in 'src\IUS.Describer.Fake.pas',
  IUS.Describer.Native in 'src\IUS.Describer.Native.pas';
```

- [ ] **Step 4.5: Register in `ImageUpscaleService.Tests.dproj`**

Add two more `<DCCReference>` entries inside the `<ItemGroup>` in `tests/ImageUpscaleService.Tests.dproj`:

```xml
        <DCCReference Include="..\src\IUS.Describer.Native.pas"/>
        <DCCReference Include="IUS.Tests.Describer.Native.pas"/>
```

- [ ] **Step 4.6: Run tests, verify pass**

Run the suite. Expected: 4 new passing tests in `TNativeDescriberTests` (the `BuildRequestBody_*` group). All other tests still pass.

- [ ] **Step 4.7: Commit**

```bash
git add ImageUpscaleService/src/IUS.Describer.Native.pas \
        ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas \
        ImageUpscaleService/ImageUpscaleService.dpr \
        ImageUpscaleService/tests/ImageUpscaleService.Tests.dproj
git commit -m "feat(imageupscaleservice): add native describer request body builder"
```

---

## Task 5: `TNativeDescriber.ExtractDescription` (TDD)

**Files:**
- Modify: `ImageUpscaleService/src/IUS.Describer.Native.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas`

- [ ] **Step 5.1: Add the failing tests**

Append the following tests to the `TNativeDescriberTests` declaration in `IUS.Tests.Describer.Native.pas`:

```pascal
    [Test] procedure ExtractDescription_ParsesValidStructuredResponse;
    [Test] procedure ExtractDescription_RaisesEmptyResult_WhenNoCandidates;
    [Test] procedure ExtractDescription_RaisesEmptyResult_WhenJsonInvalid;
    [Test] procedure ExtractDescription_RaisesEmptyResult_WhenMissingTitle;
```

And in the `implementation` section of the test unit, add the four procedures:

```pascal
procedure TNativeDescriberTests.ExtractDescription_ParsesValidStructuredResponse;
var
  LDescriber: TNativeDescriber;
  LDesc: TDescription;
const
  // Captured-fixture-style: the inner text is the JSON the model returned.
  cResponse =
    '{"candidates":[{"content":{"parts":[{"text":' +
    '"{\"title\":\"Alpine sunset\",\"caption\":\"A snow-capped peak ' +
    'reflects in a still lake.\"}"}]}}]}';
begin
  LDescriber := MakeDescriber;
  try
    LDesc := LDescriber.ExtractDescription(cResponse);
    Assert.AreEqual('Alpine sunset', LDesc.Title);
    Assert.AreEqual('A snow-capped peak reflects in a still lake.', LDesc.Caption);
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.ExtractDescription_RaisesEmptyResult_WhenNoCandidates;
var LDescriber: TNativeDescriber;
begin
  LDescriber := MakeDescriber;
  try
    Assert.WillRaise(
      procedure begin LDescriber.ExtractDescription('{"candidates":[]}'); end,
      EDescriberEmptyResultError);
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.ExtractDescription_RaisesEmptyResult_WhenJsonInvalid;
var LDescriber: TNativeDescriber;
begin
  LDescriber := MakeDescriber;
  try
    Assert.WillRaise(
      procedure begin LDescriber.ExtractDescription('not json at all'); end,
      EDescriberEmptyResultError);
  finally
    LDescriber.Free;
  end;
end;

procedure TNativeDescriberTests.ExtractDescription_RaisesEmptyResult_WhenMissingTitle;
var LDescriber: TNativeDescriber;
const
  cResponse =
    '{"candidates":[{"content":{"parts":[{"text":' +
    '"{\"caption\":\"only a caption\"}"}]}}]}';
begin
  LDescriber := MakeDescriber;
  try
    Assert.WillRaise(
      procedure begin LDescriber.ExtractDescription(cResponse); end,
      EDescriberEmptyResultError);
  finally
    LDescriber.Free;
  end;
end;
```

Also add `IUS.Describer.Intf` to the test unit's implementation `uses` clause if not already present (for `EDescriberEmptyResultError` and `TDescription`). The existing `uses` already has `IUS.Describer.Native` which transitively re-exports `TDescription` via the interface — but adding `IUS.Describer.Intf` directly is cleaner. Final implementation `uses` clause:

```pascal
uses
  System.SysUtils,
  System.NetEncoding,
  System.JSON,
  IUS.Describer.Intf,
  IUS.Describer.Native,
  IUS.DescribePrompt;
```

- [ ] **Step 5.2: Verify the new tests fail**

The four new tests should fail because `ExtractDescription` currently raises `not implemented yet`.

- [ ] **Step 5.3: Implement `ExtractDescription`**

In `IUS.Describer.Native.pas`, replace the placeholder body of `ExtractDescription` with:

```pascal
function TNativeDescriber.ExtractDescription(const AResponseBody: string): TDescription;
var
  LRoot, LCandidate, LContent, LPart, LInner: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LText: string;
  I: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(AResponseBody) as TJSONObject;
  if LRoot = nil then
    raise EDescriberEmptyResultError.Create('Response is not valid JSON');
  try
    LCandidates := LRoot.GetValue<TJSONArray>('candidates');
    if (LCandidates = nil) or (LCandidates.Count = 0) then
      raise EDescriberEmptyResultError.Create('No candidates in response');
    LCandidate := LCandidates.Items[0] as TJSONObject;
    LContent := LCandidate.GetValue<TJSONObject>('content');
    LParts := LContent.GetValue<TJSONArray>('parts');
    LText := '';
    for I := 0 to LParts.Count - 1 do
    begin
      LPart := LParts.Items[I] as TJSONObject;
      if LPart.TryGetValue<string>('text', LText) and (LText <> '') then
        Break;
    end;
    if LText = '' then
      raise EDescriberEmptyResultError.Create('No text part in response');

    // The text part itself is the JSON object enforced by responseSchema.
    LInner := TJSONObject.ParseJSONValue(LText) as TJSONObject;
    if LInner = nil then
      raise EDescriberEmptyResultError.Create('Inner text is not JSON');
    try
      if not LInner.TryGetValue<string>('title', Result.Title) or
         (Trim(Result.Title) = '') then
        raise EDescriberEmptyResultError.Create('Missing title field');
      if not LInner.TryGetValue<string>('caption', Result.Caption) or
         (Trim(Result.Caption) = '') then
        raise EDescriberEmptyResultError.Create('Missing caption field');
    finally
      LInner.Free;
    end;
  finally
    LRoot.Free;
  end;
end;
```

- [ ] **Step 5.4: Run tests, verify pass**

Run the suite. Expected: the 4 new tests pass, total `TNativeDescriberTests` = 8 passing.

- [ ] **Step 5.5: Commit**

```bash
git add ImageUpscaleService/src/IUS.Describer.Native.pas \
        ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas
git commit -m "feat(imageupscaleservice): parse Gemini structured-output describe response"
```

---

## Task 6: `TNativeDescriber.Describe` — HTTP + status code mapping

**Files:**
- Modify: `ImageUpscaleService/src/IUS.Describer.Native.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas`

We won't make live HTTP calls in tests. Instead, we extract a small helper `MapStatusCode` and test it directly. The HTTP body of `Describe` itself is exercised end-to-end via the worker integration test in Task 8.

- [ ] **Step 6.1: Write the failing tests**

Append to the test fixture declaration:

```pascal
    [Test] procedure MapStatusCode_429_RaisesQuota;
    [Test] procedure MapStatusCode_500_RaisesServer;
    [Test] procedure MapStatusCode_503_RaisesServer;
    [Test] procedure MapStatusCode_400_RaisesRejected;
    [Test] procedure MapStatusCode_403_RaisesRejected;
    [Test] procedure MapStatusCode_404_RaisesRejected;
    [Test] procedure MapStatusCode_418_RaisesRejected;
    [Test] procedure MapStatusCode_200_DoesNotRaise;
```

In implementation:

```pascal
procedure TNativeDescriberTests.MapStatusCode_429_RaisesQuota;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(429, 'rate'); end,
    EDescriberQuotaError);
end;

procedure TNativeDescriberTests.MapStatusCode_500_RaisesServer;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(500, 'oops'); end,
    EDescriberServerError);
end;

procedure TNativeDescriberTests.MapStatusCode_503_RaisesServer;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(503, 'unavailable'); end,
    EDescriberServerError);
end;

procedure TNativeDescriberTests.MapStatusCode_400_RaisesRejected;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(400, 'bad'); end,
    EDescriberRejectedError);
end;

procedure TNativeDescriberTests.MapStatusCode_403_RaisesRejected;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(403, 'forbidden'); end,
    EDescriberRejectedError);
end;

procedure TNativeDescriberTests.MapStatusCode_404_RaisesRejected;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(404, 'not found'); end,
    EDescriberRejectedError);
end;

procedure TNativeDescriberTests.MapStatusCode_418_RaisesRejected;
begin
  Assert.WillRaise(
    procedure begin TNativeDescriber.MapStatusCode(418, 'teapot'); end,
    EDescriberRejectedError);
end;

procedure TNativeDescriberTests.MapStatusCode_200_DoesNotRaise;
begin
  // Should not raise.
  TNativeDescriber.MapStatusCode(200, '');
  Assert.Pass;
end;
```

- [ ] **Step 6.2: Verify the new tests fail to compile**

`MapStatusCode` doesn't exist yet.

- [ ] **Step 6.3: Add `MapStatusCode` and finish `Describe`**

Edit `IUS.Describer.Native.pas`. Add a class method declaration in the public section:

```pascal
type
  TNativeDescriber = class(TInterfacedObject, IDescriber)
  strict private
    FApiKey: string;
    FModel: string;
  public
    constructor Create(const AApiKey, AModel: string);
    function BuildRequestBody(const AImage: TBytes; const AImageMime: string): string;
    function ExtractDescription(const AResponseBody: string): TDescription;
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
    /// <summary>Maps an HTTP status code to an EDescriber* exception.
    ///   Class method so tests can drive it directly.</summary>
    class procedure MapStatusCode(const AStatusCode: Integer; const ABody: string); static;
  end;
```

Add the implementation:

```pascal
class procedure TNativeDescriber.MapStatusCode(const AStatusCode: Integer;
                                               const ABody: string);
begin
  case AStatusCode of
    200: ; // ok
    429: raise EDescriberQuotaError.Create('429 quota');
    400, 403, 404:
      raise EDescriberRejectedError.CreateFmt('%d %s', [AStatusCode, ABody]);
    500..599:
      raise EDescriberServerError.CreateFmt('%d %s', [AStatusCode, ABody]);
  else
    raise EDescriberRejectedError.CreateFmt('%d %s', [AStatusCode, ABody]);
  end;
end;
```

Replace the placeholder `Describe` with:

```pascal
function TNativeDescriber.Describe(const AImage: TBytes;
                                   const AImageMime: string): TDescription;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LUrl: string;
begin
  LClient := TNetHTTPClient.Create(nil);
  LRequest := TNetHTTPRequest.Create(nil);
  LBody := TStringStream.Create(BuildRequestBody(AImage, AImageMime), TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := 30000;
    LClient.ResponseTimeout   := 30000;
    LRequest.Client := LClient;
    LRequest.CustomHeaders['x-goog-api-key'] := FApiKey;
    LRequest.CustomHeaders['Content-Type']   := 'application/json';
    LUrl := Format(
      'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent',
      [FModel]);

    try
      LResponse := LRequest.Post(LUrl, LBody);
    except
      on E: ENetHTTPClientException do
        raise EDescriberNetworkError.Create('Network error: ' + E.Message);
    end;

    MapStatusCode(LResponse.StatusCode, LResponse.ContentAsString);
    Result := ExtractDescription(LResponse.ContentAsString);
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;
```

- [ ] **Step 6.4: Run tests, verify pass**

Run the suite. Expected: 8 new `MapStatusCode_*` tests pass, no regressions.

- [ ] **Step 6.5: Commit**

```bash
git add ImageUpscaleService/src/IUS.Describer.Native.pas \
        ImageUpscaleService/tests/IUS.Tests.Describer.Native.pas
git commit -m "feat(imageupscaleservice): finish native describer with HTTP + status mapping"
```

---

## Task 7: `IUS.Config` — read `[Describer] Model=`

**Files:**
- Modify: `ImageUpscaleService/src/IUS.Config.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.Config.pas`
- Modify: `ImageUpscaleService/config.ini.example`

- [ ] **Step 7.1: Read existing config tests for the pattern**

Open `ImageUpscaleService/tests/IUS.Tests.Config.pas` to see how existing keys are tested. Mirror that style.

- [ ] **Step 7.2: Write the failing test**

Append a new test to `IUS.Tests.Config.pas`:

```pascal
    [Test] procedure DescribeModel_DefaultsTo_3_1_FlashLite_Preview;
    [Test] procedure DescribeModel_OverriddenInIniFile;
```

Implementation (adapt to whatever helper the existing tests use to write a temp ini — most likely `TFile.WriteAllText` to a temp path then `LoadConfig`):

```pascal
procedure TConfigTests.DescribeModel_DefaultsTo_3_1_FlashLite_Preview;
var LCfg: TConfig; LPath: string;
begin
  LPath := WriteTempIni(
    '[Server]'#13#10'Port=8080'#13#10 +
    '[Gemini]'#13#10'ApiKey=AIzaTEST'#13#10);
  try
    LCfg := LoadConfig(LPath);
    Assert.AreEqual('gemini-3.1-flash-lite-preview', LCfg.DescribeModel);
  finally
    TFile.Delete(LPath);
  end;
end;

procedure TConfigTests.DescribeModel_OverriddenInIniFile;
var LCfg: TConfig; LPath: string;
begin
  LPath := WriteTempIni(
    '[Server]'#13#10'Port=8080'#13#10 +
    '[Gemini]'#13#10'ApiKey=AIzaTEST'#13#10 +
    '[Describer]'#13#10'Model=gemini-3-flash-preview'#13#10);
  try
    LCfg := LoadConfig(LPath);
    Assert.AreEqual('gemini-3-flash-preview', LCfg.DescribeModel);
  finally
    TFile.Delete(LPath);
  end;
end;
```

If the existing test file does not have a `WriteTempIni` helper, copy the pattern used by another test in the same file (look for `TPath.GetTempFileName` + `TFile.WriteAllText`).

- [ ] **Step 7.3: Verify they fail**

Compile error: `TConfig.DescribeModel` doesn't exist.

- [ ] **Step 7.4: Add the field and the loader line**

In `ImageUpscaleService/src/IUS.Config.pas`, add `DescribeModel: string;` to `TConfig`:

```pascal
  TConfig = record
    Port: Integer;
    ApiKey: string;
    Model: string;
    Provider: string; // 'native' | 'delphigemini'
    UploadDir: string;
    ResultDir: string;
    RetentionMinutes: Integer;
    DescribeModel: string;
  end;
```

In `LoadConfig`, after the existing `RetentionMinutes` line, add:

```pascal
    Result.DescribeModel := LIni.ReadString('Describer', 'Model',
      'gemini-3.1-flash-lite-preview');
```

- [ ] **Step 7.5: Update `config.ini.example`**

Append after the `[Storage]` section:

```ini

[Describer]
; Gemini Flash model used to describe the upscaled image after a job
; succeeds. The describe call is async, fire-and-forget; failures here
; never affect the upscale result.
Model=gemini-3.1-flash-lite-preview
```

- [ ] **Step 7.6: Run tests, verify pass**

Run the suite. The two new config tests pass; no regressions.

- [ ] **Step 7.7: Commit**

```bash
git add ImageUpscaleService/src/IUS.Config.pas \
        ImageUpscaleService/tests/IUS.Tests.Config.pas \
        ImageUpscaleService/config.ini.example
git commit -m "feat(imageupscaleservice): config key for describer model"
```

---

## Task 8: `IUS.JobQueue` — extend `TJob` and add describe setters

**Files:**
- Modify: `ImageUpscaleService/src/IUS.JobQueue.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.JobQueue.pas`

This task only adds the data + setters. Worker fan-out is in Task 9.

- [ ] **Step 8.1: Write the failing tests**

Append the following tests to `TJobQueueTests` in `IUS.Tests.JobQueue.pas`:

```pascal
    [Test] procedure NewJob_DescribeStatusIsNotRequested;
    [Test] procedure SetDescribeRunning_TransitionsState;
    [Test] procedure SetDescribeDone_StoresTitleAndCaption;
    [Test] procedure SetDescribeFailed_TransitionsState;
```

Implementation (add the test bodies to the same file — note the existing `MakeJob` helper is reused):

```pascal
procedure TJobQueueTests.NewJob_DescribeStatusIsNotRequested;
var
  LQueue: TJobQueue;
  LId: TGuid;
  LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId := MakeJob(LQueue);
    Assert.IsTrue(LQueue.TryGet(LId, LFetched));
    Assert.AreEqual(Ord(TDescribeStatus.NotRequested), Ord(LFetched.DescribeStatus));
    Assert.AreEqual('', LFetched.DescribeTitle);
    Assert.AreEqual('', LFetched.DescribeCaption);
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.SetDescribeRunning_TransitionsState;
var
  LQueue: TJobQueue;
  LId: TGuid;
  LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId := MakeJob(LQueue);
    LQueue.SetDescribeRunning(LId);
    Assert.IsTrue(LQueue.TryGet(LId, LFetched));
    Assert.AreEqual(Ord(TDescribeStatus.Running), Ord(LFetched.DescribeStatus));
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.SetDescribeDone_StoresTitleAndCaption;
var
  LQueue: TJobQueue;
  LId: TGuid;
  LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId := MakeJob(LQueue);
    LQueue.SetDescribeDone(LId, 'Alpine sunset', 'Snow-capped peak in still water.');
    Assert.IsTrue(LQueue.TryGet(LId, LFetched));
    Assert.AreEqual(Ord(TDescribeStatus.Done), Ord(LFetched.DescribeStatus));
    Assert.AreEqual('Alpine sunset', LFetched.DescribeTitle);
    Assert.AreEqual('Snow-capped peak in still water.', LFetched.DescribeCaption);
  finally
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.SetDescribeFailed_TransitionsState;
var
  LQueue: TJobQueue;
  LId: TGuid;
  LFetched: TJob;
begin
  LQueue := TJobQueue.Create(20);
  try
    LId := MakeJob(LQueue);
    LQueue.SetDescribeFailed(LId);
    Assert.IsTrue(LQueue.TryGet(LId, LFetched));
    Assert.AreEqual(Ord(TDescribeStatus.Failed), Ord(LFetched.DescribeStatus));
  finally
    LQueue.Free;
  end;
end;
```

- [ ] **Step 8.2: Verify they fail**

Compile error: `TDescribeStatus`, the new `TJob` fields, and the setters don't exist yet.

- [ ] **Step 8.3: Extend `TJob` and add setters in `IUS.JobQueue.pas`**

In the interface section, add `TDescribeStatus` before `TJob`:

```pascal
type
  TJobStatus = (Queued, Running, Done, Error);

  TDescribeStatus = (NotRequested, Running, Done, Failed);

  TJob = record
    Id: TGuid;
    Status: TJobStatus;
    CreatedAt: TDateTime;
    SourceMime: string;
    SourcePath: string;
    ResultPath: string;
    Resolution: TUpscaleResolution;
    ErrorMsg: string;
    DescribeStatus:  TDescribeStatus;
    DescribeTitle:   string;
    DescribeCaption: string;
  end;
```

> Note: the workshop already uses scoped enums (`{$SCOPEDENUMS ON}` is at the top of this unit), so `TJobStatus.Done` and `TDescribeStatus.Done` are different values and the compiler will treat them as such.

Add three new method declarations to the `TJobQueue` `public` section, after `SetResult`:

```pascal
    procedure SetDescribeRunning(const AId: TGuid);
    procedure SetDescribeDone(const AId: TGuid; const ATitle, ACaption: string);
    procedure SetDescribeFailed(const AId: TGuid);
```

Add the implementations after `SetResult`:

```pascal
procedure TJobQueue.SetDescribeRunning(const AId: TGuid);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus := TDescribeStatus.Running;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetDescribeDone(const AId: TGuid; const ATitle, ACaption: string);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus  := TDescribeStatus.Done;
      LJob.DescribeTitle   := ATitle;
      LJob.DescribeCaption := ACaption;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TJobQueue.SetDescribeFailed(const AId: TGuid);
var
  LJob: TJob;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(AId, LJob) then
    begin
      LJob.DescribeStatus := TDescribeStatus.Failed;
      FById.AddOrSetValue(AId, LJob);
    end;
  finally
    FLock.Leave;
  end;
end;
```

The `Default(TJob)` in `TryEnqueue` already zero-initializes everything — `DescribeStatus` will start as `NotRequested` (ordinal 0).

- [ ] **Step 8.4: Run tests, verify pass**

Run the suite. The 4 new `TJobQueueTests.*` tests pass; no regressions.

- [ ] **Step 8.5: Commit**

```bash
git add ImageUpscaleService/src/IUS.JobQueue.pas \
        ImageUpscaleService/tests/IUS.Tests.JobQueue.pas
git commit -m "feat(imageupscaleservice): add describe status and setters to TJob"
```

---

## Task 9: Worker fan-out — describe thread after upscale done

**Files:**
- Modify: `ImageUpscaleService/src/IUS.JobQueue.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.JobQueue.pas`

- [ ] **Step 9.1: Write the failing test**

Append two tests to `TJobQueueTests`:

```pascal
    [Test] procedure Workers_RunDescriber_AfterUpscaleSucceeds;
    [Test] procedure Workers_DescribeFails_DoesNotAffectJobStatus;
```

Implementation (uses both `TFakeUpscaler` and `TFakeDescriber`):

```pascal
procedure TJobQueueTests.Workers_RunDescriber_AfterUpscaleSucceeds;
var
  LQueue: TJobQueue;
  LFakeUp: TFakeUpscaler;
  LFakeDesc: TFakeDescriber;
  LJob, LFetched: TJob;
  LDeadline: TDateTime;
  LTmp: string;
begin
  LQueue := TJobQueue.Create(20);
  try
    LFakeUp := TFakeUpscaler.Create;
    LFakeDesc := TFakeDescriber.Create;
    LQueue.StartWorkers(2, LFakeUp, LFakeDesc, TPath.GetTempPath);

    LTmp := TPath.Combine(TPath.GetTempPath, 'src_' + TGuid.NewGuid.ToString + '.png');
    TFile.WriteAllBytes(LTmp, TBytes.Create($89, $50, $4E, $47));
    try
      Assert.IsTrue(LQueue.TryEnqueue('image/png', LTmp, TUpscaleResolution.Res2K, LJob));
      // Wait for the upscale + describe pair to complete.
      LDeadline := IncSecond(Now, 5);
      repeat
        Sleep(50);
        Assert.IsTrue(LQueue.TryGet(LJob.Id, LFetched));
      until (LFetched.DescribeStatus in [TDescribeStatus.Done, TDescribeStatus.Failed])
            or (Now > LDeadline);

      Assert.AreEqual(Ord(TJobStatus.Done),       Ord(LFetched.Status), LFetched.ErrorMsg);
      Assert.AreEqual(Ord(TDescribeStatus.Done),  Ord(LFetched.DescribeStatus));
      Assert.IsTrue(Length(LFetched.DescribeTitle)   > 0);
      Assert.IsTrue(Length(LFetched.DescribeCaption) > 0);
      Assert.AreEqual(1, LFakeDesc.CallCount);
    finally
      if TFile.Exists(LTmp) then TFile.Delete(LTmp);
    end;
  finally
    LQueue.StopWorkers;
    LQueue.Free;
  end;
end;

procedure TJobQueueTests.Workers_DescribeFails_DoesNotAffectJobStatus;
var
  LQueue: TJobQueue;
  LFakeUp: TFakeUpscaler;
  LFakeDesc: TFakeDescriber;
  LJob, LFetched: TJob;
  LDeadline: TDateTime;
  LTmp: string;
begin
  LQueue := TJobQueue.Create(20);
  try
    LFakeUp := TFakeUpscaler.Create;
    LFakeDesc := TFakeDescriber.Create;
    LFakeDesc.RaiseOnNextCall(EDescriberQuotaError);
    LQueue.StartWorkers(2, LFakeUp, LFakeDesc, TPath.GetTempPath);

    LTmp := TPath.Combine(TPath.GetTempPath, 'src_' + TGuid.NewGuid.ToString + '.png');
    TFile.WriteAllBytes(LTmp, TBytes.Create($89, $50, $4E, $47));
    try
      Assert.IsTrue(LQueue.TryEnqueue('image/png', LTmp, TUpscaleResolution.Res2K, LJob));
      LDeadline := IncSecond(Now, 5);
      repeat
        Sleep(50);
        Assert.IsTrue(LQueue.TryGet(LJob.Id, LFetched));
      until (LFetched.DescribeStatus in [TDescribeStatus.Done, TDescribeStatus.Failed])
            or (Now > LDeadline);

      // Upscale still succeeded.
      Assert.AreEqual(Ord(TJobStatus.Done),         Ord(LFetched.Status), LFetched.ErrorMsg);
      // But describe failed silently.
      Assert.AreEqual(Ord(TDescribeStatus.Failed),  Ord(LFetched.DescribeStatus));
      Assert.AreEqual('', LFetched.DescribeTitle);
      Assert.AreEqual('', LFetched.DescribeCaption);
    finally
      if TFile.Exists(LTmp) then TFile.Delete(LTmp);
    end;
  finally
    LQueue.StopWorkers;
    LQueue.Free;
  end;
end;
```

Add to the `uses` clause in the implementation section: `IUS.Describer.Intf, IUS.Describer.Fake`.

Update the existing `Workers_ProcessQueuedJob_AndMarkDone` test signature to also pass a fake describer (the existing test must keep compiling once `StartWorkers` requires four parameters):

In its body, replace:
```pascal
    LFake := TFakeUpscaler.Create;
    LQueue.StartWorkers(3, LFake, TPath.GetTempPath);
```
with:
```pascal
    LFake := TFakeUpscaler.Create;
    LQueue.StartWorkers(3, LFake, TFakeDescriber.Create, TPath.GetTempPath);
```

- [ ] **Step 9.2: Verify they fail**

Compile error: `StartWorkers` doesn't accept an `IDescriber` yet.

- [ ] **Step 9.3: Modify `StartWorkers` and worker body**

In `IUS.JobQueue.pas`:

a) Add a private field `FDescriber: IDescriber;` next to `FUpscaler`. Add `IUS.Describer.Intf` to the interface `uses` clause.

b) Change the `StartWorkers` declaration:

```pascal
    procedure StartWorkers(const ACount: Integer;
                           const AUpscaler:  IUpscaler;
                           const ADescriber: IDescriber;
                           const AResultDir: string);
```

c) Change the implementation:

```pascal
procedure TJobQueue.StartWorkers(const ACount: Integer;
                                 const AUpscaler:  IUpscaler;
                                 const ADescriber: IDescriber;
                                 const AResultDir: string);
var
  I: Integer;
begin
  FUpscaler := AUpscaler;
  FDescriber := ADescriber;
  FResultDir := AResultDir;
  IUS.Storage.EnsureDirectory(FResultDir);
  FRunning := True;
  SetLength(FWorkers, ACount);
  for I := 0 to ACount - 1 do
    FWorkers[I] := TThread.CreateAnonymousThread(
      procedure
      var LJob: TJob; LSource, LResult: TBytes; LResultPath: string;
      begin
        while FRunning do
        begin
          if TryDequeue(LJob) then
          try
            Writeln(Format('job=%s queued->running', [Copy(LJob.Id.ToString, 2, 8)]));
            SetStatus(LJob.Id, TJobStatus.Running);
            LSource := IUS.Storage.ReadAllBytes(LJob.SourcePath);
            LResult := FUpscaler.Upscale(LSource, LJob.SourceMime, LJob.Resolution);
            LResultPath := TPath.Combine(FResultDir, LJob.Id.ToString + '.png');
            IUS.Storage.WriteAllBytes(LResultPath, LResult);
            SetResult(LJob.Id, LResultPath);
            Writeln(Format('job=%s running->done', [Copy(LJob.Id.ToString, 2, 8)]));

            // Fire-and-forget describer. Status flips to Running so the
            // /describe/:id route can show the polling fragment immediately.
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
          except
            on E: Exception do
            begin
              SetError(LJob.Id, E.Message);
              Writeln(Format('job=%s running->error: %s',
                [Copy(LJob.Id.ToString, 2, 8), E.Message]));
            end;
          end
          else
            Sleep(50);
        end;
      end);
  for I := 0 to ACount - 1 do
  begin
    FWorkers[I].FreeOnTerminate := False;
    FWorkers[I].Start;
  end;
end;
```

> The describe thread's `LResultPath` and `LJob.Id` are captured from the surrounding closure. They are simple value types (string, TGuid) so each iteration's capture is independent. `LDesc`/`LBytes` are declared inside the inner closure to avoid the classic "all closures share the same loop variable" trap.

> Anonymous threads default to `FreeOnTerminate := True` in Delphi, so the describe thread cleans itself up. We do **not** track it in `FWorkers`.

d) The implementation `uses` clause needs `IUS.Describer.Intf` added (for `TDescription`).

- [ ] **Step 9.4: Run tests, verify pass**

Expected: the 2 new fan-out tests pass; the existing `Workers_ProcessQueuedJob_AndMarkDone` still passes (with its updated signature). No regressions.

- [ ] **Step 9.5: Commit**

```bash
git add ImageUpscaleService/src/IUS.JobQueue.pas \
        ImageUpscaleService/tests/IUS.Tests.JobQueue.pas
git commit -m "feat(imageupscaleservice): worker fans out describer after upscale done"
```

---

## Task 10: `IUS.Routes` — `GET /describe/:id` and render helpers

**Files:**
- Modify: `ImageUpscaleService/src/IUS.Routes.pas`
- (No new tests — route logic is exercised by the smoke test in Task 13.)

- [ ] **Step 10.1: Add render helpers**

In `IUS.Routes.pas`, add two private method declarations to `TRoutesContext` next to `RenderDone`:

```pascal
    function RenderDescribePending(const AJob: TJob): string;
    function RenderDescribeDone(const AJob: TJob): string;
```

Add the implementations (next to `RenderDone`):

```pascal
function TRoutesContext.RenderDescribePending(const AJob: TJob): string;
begin
  Result := RenderPage('describe_pending.html',
    ['jobId', AJob.Id.ToString]);
end;

function TRoutesContext.RenderDescribeDone(const AJob: TJob): string;
begin
  Result := RenderPage('describe_done.html',
    ['title',   AJob.DescribeTitle,
     'caption', AJob.DescribeCaption]);
end;
```

- [ ] **Step 10.2: Add the route**

In the `Register` method, after `THorse.Get('/result/:id', ...)` and before `THorse.Get('/static/:filename', ...)`, add:

```pascal
  THorse.Get('/describe/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LId: TGuid;
      LJob: TJob;
    begin
      if not LSelf.TryParseJobId(Req.Params['id'], LId) then
      begin
        Res.Status(404).Send('');
        Exit;
      end;
      if not LSelf.FQueue.TryGet(LId, LJob) then
      begin
        Res.Status(404).Send('');
        Exit;
      end;
      case LJob.DescribeStatus of
        TDescribeStatus.NotRequested,
        TDescribeStatus.Running:
          Res.Send(LSelf.RenderDescribePending(LJob));
        TDescribeStatus.Done:
          Res.Send(LSelf.RenderDescribeDone(LJob));
        TDescribeStatus.Failed:
          Res.Send(''); // empty body collapses the slot, silent fail.
      end;
    end);
```

- [ ] **Step 10.3: Verify build**

Build the main exe (or compile in IDE). Expected: clean compile.

- [ ] **Step 10.4: Commit**

```bash
git add ImageUpscaleService/src/IUS.Routes.pas
git commit -m "feat(imageupscaleservice): add GET /describe/:id route and renderers"
```

---

## Task 11: Templates — `describe_pending.html`, `describe_done.html`, modify `job_done.html`

**Files:**
- Create: `ImageUpscaleService/templates/describe_pending.html`
- Create: `ImageUpscaleService/templates/describe_done.html`
- Modify: `ImageUpscaleService/templates/job_done.html`

- [ ] **Step 11.1: Create `describe_pending.html`**

```html
<div class="describe-slot describe-pending"
     hx-get="/describe/@jobId"
     hx-trigger="load delay:1s"
     hx-swap="outerHTML">
  <span class="describe-spinner"></span>
  <span>Analysing image&hellip;</span>
</div>
```

This fragment self-replaces every 1 s. When status flips to `Done` the response is `describe_done.html` (no `hx-trigger`), polling stops naturally. When status flips to `Failed` the response is empty, the slot is removed.

- [ ] **Step 11.2: Create `describe_done.html`**

```html
<div class="describe-slot describe-done">
  <h2 class="describe-title">@title</h2>
  <p class="describe-caption">@caption</p>
</div>
```

- [ ] **Step 11.3: Modify `job_done.html`**

Insert the polling slot between `</div>` (closing `.compare-grid`) and the `<div class="actions-row">`:

```html
<div class="result-section">
  <div class="compare-grid">
    <div class="compare-item">
      <img src="/original/@jobId" alt="Original image before upscaling">
      <div class="compare-label">
        <span class="badge badge-original">Before</span>
        Original
      </div>
    </div>
    <div class="compare-item">
      <img src="/result/@jobId" alt="Remastered image at @resolutionText resolution">
      <div class="compare-label">
        <span class="badge badge-result">After</span>
        Remastered &middot; @resolutionText
      </div>
    </div>
  </div>
  <div class="describe-slot"
       hx-get="/describe/@jobId"
       hx-trigger="load delay:300ms"
       hx-swap="outerHTML">
  </div>
  <div class="actions-row">
    <a href="/result/@jobId" download="upscaled.png" class="btn btn-primary">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
      Download Result
    </a>
    <a hx-get="/" hx-target="#content" hx-swap="innerHTML" href="#" class="btn btn-ghost">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>
      Try Another
    </a>
  </div>
</div>
```

- [ ] **Step 11.4: Commit**

```bash
git add ImageUpscaleService/templates/describe_pending.html \
        ImageUpscaleService/templates/describe_done.html \
        ImageUpscaleService/templates/job_done.html
git commit -m "feat(imageupscaleservice): templates for async description block"
```

---

## Task 12: CSS — `.describe-*` styles

**Files:**
- Modify: `ImageUpscaleService/public/app.css`

- [ ] **Step 12.1: Append the describe block**

At the bottom of `app.css`, append:

```css
/* --- Description block ------------------------------------ */
.describe-slot {
  margin-top: 24px;
  padding-top: 20px;
  border-top: 1px solid var(--border-subtle);
}

.describe-pending {
  display: flex;
  align-items: center;
  gap: 10px;
  color: var(--text-secondary);
  font-size: 13px;
}

.describe-spinner {
  width: 14px;
  height: 14px;
  border: 2px solid var(--border);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: describe-spin 0.7s linear infinite;
  display: inline-block;
}

@keyframes describe-spin {
  to { transform: rotate(360deg); }
}

.describe-done {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.describe-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--accent-hover);
  margin: 0;
  letter-spacing: -0.01em;
}

.describe-caption {
  font-size: 14px;
  color: var(--text-secondary);
  margin: 0;
  line-height: 1.55;
}
```

- [ ] **Step 12.2: Commit**

```bash
git add ImageUpscaleService/public/app.css
git commit -m "feat(imageupscaleservice): styles for description block"
```

---

## Task 13: `IUS.Server` — wire `TNativeDescriber`

**Files:**
- Modify: `ImageUpscaleService/src/IUS.Server.pas`
- Modify: `ImageUpscaleService/tests/IUS.Tests.Smoke.pas` (if it constructs the queue)

- [ ] **Step 13.1: Update `IUS.Server.pas`**

Add `IUS.Describer.Intf, IUS.Describer.Native, IUS.DescribePrompt` to the implementation `uses` clause.

Add a new builder helper next to `BuildUpscaler`:

```pascal
function BuildDescriber(const ACfg: TConfig): IDescriber;
begin
  Result := TNativeDescriber.Create(ACfg.ApiKey, ACfg.DescribeModel);
end;
```

Add the local var and the construction in `RunServer`:

```pascal
var
  ...
  LUpscaler: IUpscaler;
  LDescriber: IDescriber;
  ...
begin
  ...
  LUpscaler := BuildUpscaler(LCfg);
  LDescriber := BuildDescriber(LCfg);
  ...
```

Update the `StartWorkers` call to pass the describer:

```pascal
    LQueue.StartWorkers(3, LUpscaler, LDescriber, LResultDir);
```

Add to the existing log line block:

```pascal
    Writeln(Format('Upscaler model:  %s', [LCfg.Model]));
    Writeln(Format('Describer model: %s', [LCfg.DescribeModel]));
```

(Place after the existing `Writeln('Loaded remaster prompt, ...')` so the workshop sees both models on startup.)

- [ ] **Step 13.2: Check the smoke test**

Open `ImageUpscaleService/tests/IUS.Tests.Smoke.pas`. If it calls `StartWorkers`, update the call to pass a `TFakeDescriber` (just like Task 9 updated `Workers_ProcessQueuedJob_AndMarkDone`). If the smoke test does not call `StartWorkers` directly, no change is needed.

(You may need to add `IUS.Describer.Fake, IUS.Describer.Intf` to its `uses` clause.)

- [ ] **Step 13.3: Build, run tests, verify pass**

Build both the test exe and the main exe. Expected: clean compile of both, full test suite passes.

- [ ] **Step 13.4: Commit**

```bash
git add ImageUpscaleService/src/IUS.Server.pas ImageUpscaleService/tests/IUS.Tests.Smoke.pas
git commit -m "feat(imageupscaleservice): wire describer into server composition root"
```

---

## Task 14: End-to-end manual verification

**Files:**
- (Manual only — no code change.)

- [ ] **Step 14.1: Update local `config.ini`**

If your existing `ImageUpscaleService/config.ini` does not yet have a `[Describer]` section, add it:

```ini
[Describer]
Model=gemini-3.1-flash-lite-preview
```

(Optional — defaults to that value if the section is omitted.)

- [ ] **Step 14.2: Build and start the server**

```bash
cd ImageUpscaleService
"C:/Program Files (x86)/Embarcadero/Studio/23.0/bin/MSBuild.exe" ImageUpscaleService.dproj //p:Config=Debug //p:Platform=Win64
./build/Win64/Debug/ImageUpscaleService.exe
```

Expected console output includes:
```
Upscaler model:  gemini-3-pro-image-preview
Describer model: gemini-3.1-flash-lite-preview
ImageUpscaleService listening on http://localhost:8080  (upscaler=native)
```

- [ ] **Step 14.3: Test in browser**

1. Open `http://localhost:8080`.
2. Upload a JPEG/PNG and submit at any resolution.
3. While the job runs, the pending state shows as before.
4. When the job completes, the before/after grid appears immediately, **then** an "Analysing image…" line shows briefly between the grid and the action buttons, **then** the title + caption block replaces it.
5. Console log shows two job lines per request: `running->done` and (a moment later) either nothing extra (success) or `job=... describe failed: ...` (failure).

- [ ] **Step 14.4: Test the failure path**

Temporarily edit `config.ini` to set an invalid describer model:
```ini
[Describer]
Model=this-model-does-not-exist
```
Restart, run a job. Expected: upscale still succeeds, the "Analysing image…" line shows briefly, then the slot disappears (silent fail). Console logs `job=... describe failed: ...`. Restore the model afterwards.

- [ ] **Step 14.5: No commit (manual test only)**

If any issue surfaces, file/fix as a follow-up commit referencing the task.

---

## Self-Review

**1. Spec coverage**

| Spec section | Plan task |
|---|---|
| Async two-phase timing | Task 9 (worker fan-out) + Task 10 (route) + Task 11 (templates) |
| Title + caption shape | Task 1 (`TDescription`) + Task 5 (`ExtractDescription`) + Task 11 (`describe_done.html`) |
| English-only | Task 2 (prompt is English) — no language switch in plan |
| `gemini-3.1-flash-lite-preview` default + `[Describer] Model=` | Task 7 (config) + Task 13 (server wires `LCfg.DescribeModel`) |
| Silent soft-fail | Task 9 (worker exception handler logs + `SetDescribeFailed`) + Task 10 (Failed branch returns empty body) |
| `IDescriber` parallels `IUpscaler` | Task 1 (interface), Task 4-6 (`TNativeDescriber`), Task 3 (`TFakeDescriber`) |
| `EDescriber*` exception tree | Task 1 (declared) + Task 6 (raised by `MapStatusCode`) |
| `TJob.DescribeStatus/Title/Caption` | Task 8 |
| Worker spawns describe `TThread` after `Done` | Task 9 |
| `GET /describe/:id` returns pending / done / empty fragments | Task 10 |
| `job_done.html` polling slot, `describe_pending.html` self-poll | Task 11 |
| CSS describe block (~30 lines) | Task 12 |
| Server constructs describer + StartWorkers signature | Task 13 |
| Tests: byte-exact prompt | Task 2 |
| Tests: BuildRequestBody | Task 4 |
| Tests: ExtractDescription | Task 5 |
| Tests: status-code → exception mapping | Task 6 |
| Tests: TJob fields default + setters | Task 8 |
| Tests: worker fan-out (success + silent fail) | Task 9 |
| Out of scope: language switching, caching, regen, streaming, per-resolution | Not implemented (correct — YAGNI) |

All spec items mapped.

**2. Placeholder scan**

No "TBD", "TODO", "implement later" placeholders. Every step has either complete code, an exact command, or an exact file path. The only intentional placeholder lives transiently inside Task 4-6: `Describe` and `ExtractDescription` raise `not implemented yet` after Task 4 and are filled in by Tasks 5 and 6 respectively. This is by design — small TDD increments.

**3. Type consistency**

- `TDescription` — declared in Task 1, returned by `Describe` in Tasks 3/4/5/6, consumed in Task 9. Field names `Title`, `Caption` match throughout.
- `TDescribeStatus` — declared in Task 8; values `NotRequested, Running, Done, Failed` used identically in Tasks 9 (worker) and 10 (route).
- `IDescriber.Describe(AImage: TBytes; AImageMime: string): TDescription` — same signature in Tasks 1, 3, 4, 6, 9.
- `StartWorkers(ACount, AUpscaler, ADescriber, AResultDir)` — four parameters, `IDescriber` slotted between `IUpscaler` and `AResultDir`. Same in Tasks 9 and 13 and the updated test in Task 9.
- `SetDescribeRunning / SetDescribeDone / SetDescribeFailed` — same names everywhere (Tasks 8, 9). `SetDescribeDone` takes `(AId, ATitle, ACaption)` — same in declaration, implementation, test, and worker call site.
- Config field `DescribeModel` — same name in `TConfig`, the loader, and `BuildDescriber`.
- Template variable names — `@jobId` (matches existing convention), `@title`, `@caption` (registered in Task 10's `RenderDescribeDone`).

No mismatches.
