# Architecture

```
sukkar_plus/
├── packages/sukkar_core/      Pure Dart domain logic (no Flutter, no network)
│   ├── lib/src/cgm/           metrics calculator, GMI, targets, summary checks, CSV import
│   ├── lib/src/extraction/    PDF validation, report text parser, review/correction, AI reconciliation
│   ├── lib/src/labs/          HbA1c units + lab validation
│   ├── lib/src/comparison/    GMI vs HbA1c, lab trends, CGM period comparison
│   ├── lib/src/rules/         versioned rule set + engine + 4 user-facing outcomes
│   ├── lib/src/followup/      state machine, access policy, idempotency keys
│   ├── lib/src/reminders/     reminder state transitions
│   ├── lib/src/summary/       visit-preparation summary + neutral questions
│   ├── lib/src/ai/            explanation provider abstraction, AI text guard, local templates
│   ├── lib/src/integration/   minimal automation payload, mock notifier
│   ├── lib/src/repository/    HealthRepository interface + in-memory implementation
│   └── lib/src/demo/          synthetic readings, synthetic report layout, demo seed
├── app/                       Flutter app (Arabic RTL)
│   ├── lib/core/              design tokens, theme, router, widgets, charts, Arabic formatting
│   ├── lib/data/              AppController (Riverpod), providers, Supabase repository,
│   │                          platform adapters (pdfrx, file_picker, pdf/printing), backend services
│   └── lib/features/          one folder per screen group
├── supabase/
│   ├── migrations/            schema, RLS policies, workflow RPCs
│   ├── functions/             extract-report, explain, followup-dispatch (+ _shared modules)
│   ├── tests/                 PGlite (real Postgres in WASM) RLS tests + function module tests
│   └── seed.sql               optional synthetic seed for a real project
├── make/                      Make.com scenario instructions + example payload
├── docs/                      this documentation
└── tool/                      offline test runner, Windows scripts
```

## Layers

```
 Screens (features/*) ──watch──▶ providers.dart (derived: evaluation, comparison, visit summary)
        │                                   │
        └──call──▶ AppController (Notifier<AppState>) ──uses──▶ sukkar_core (all medical logic)
                         │
       ┌─────────────────┼────────────────────────┬──────────────────────────┐
       ▼                 ▼                        ▼                          ▼
 HealthRepository   PdfTextExtractor        AiExtractionClient        FollowUpDispatcher
 ├ InMemory (demo)  └ pdfrx/PDFium          ├ NoAiExtraction (demo)   ├ MockDispatcher (demo)
 └ Supabase (live)    on device             └ EdgeAiExtraction        └ EdgeDispatcher
                                                 │                          │
                                       Supabase Edge Functions (Deno) — hold all secrets
                                       extract-report → Gemini      followup-dispatch → Make.com
                                       explain → Gemini + text guard
```

* **Demo mode** (default when no Supabase URL/key is compiled in): everything runs on the device with synthetic data in memory; no network calls are made; AI uses local templates; automation uses a labelled mock.
* **Live mode** (`--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…`): Supabase Auth, Postgres with RLS, Edge Functions. Gemini and Make.com activate only when their secrets are set on the server.

## Upload pipeline

```
pick PDF ─▶ consent check ─▶ validatePdfBytes ─▶ PDFium text (device) ─▶ ReportTextParser
   ─▶ [optional: extract-report → Gemini → server validation → device validation → reconcileWithAi]
   ─▶ applyConsistencyChecks ─▶ Extraction review (confirm / correct / unavailable, period override)
   ─▶ buildReportFromExtraction (only confirmed values become verified) ─▶ withDerivedMetrics
   ─▶ qualityFromSummary ─▶ RuleEngine.evaluate ─▶ save report + analysis run ─▶ Analysis screen
```

## Follow-up workflow

```
draft ─submit─▶ awaiting_review ─startReview─▶ under_review ─decide─┬─▶ reviewed ─close─▶ closed
  │                  │                                              └─▶ more_info_requested ─submit─▶ awaiting_review
  └──withdraw────────┴──▶ closed
```

* The same state machine exists in Dart (`FollowUpWorkflow`) and in SQL RPCs (`submit_followup`, `reviewer_start_review`, `reviewer_decide`, `close_followup`, `withdraw_followup`). Direct UPDATEs are not granted.
* Duplicate prevention: idempotency key `user|report|trigger|sorted rule ids`, enforced by a partial unique index on open requests.
* Reviewers see only submitted requests and only the `shared_snapshot` the patient approved; the `user_id` column is not granted to API clients.
* Automation: `followup-dispatch` builds a minimal pseudonymous payload, records an `integration_events` row keyed by `request:event:submissionNumber` (unique), then posts to Make.com with timeout and bounded retries (or records a mock). Failed events can be retried explicitly; sent events are never re-sent.

## State management and navigation

Riverpod 3 `NotifierProvider` holds `AppState`; derived values are plain `Provider`s. GoRouter 18 redirects on readiness, sign-in, onboarding and role. The demo banner is inserted above every route in `MaterialApp.router(builder: …)`.

## Why the core is separate

It keeps medical logic testable without Flutter, lets the same code run in tests, in the app and in tooling, and makes the "deterministic code, not the AI, computes numbers" rule structural.
