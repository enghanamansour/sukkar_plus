# سكر بلس — Sukkar Plus

**An AI-assisted diabetes follow-up companion (independent concept prototype).**
Arabic, right-to-left Flutter app that turns a CGM report and laboratory results into a dated, verified summary; compares GMI with HbA1c and earlier periods with honest caveats; tracks clinician-requested lab tests before an appointment; and offers a simulated human-review workflow with a demo reviewer dashboard.

> Not affiliated with Sehhaty, the Ministry of Health, Insulet, Dexcom or any provider. No diagnosis, emergency triage, or dose/treatment advice. Review requests are simulated and never reach a real clinician.

## What works without any external service (demo mode)

* Arabic RTL UI modelled on the reference layout, with original branding and a persistent "وضع العرض — بيانات تجريبية" banner.
* Upload → on-device PDF reading (PDFium) → deterministic extraction of the **Omnipod Discover** summary page → per-value review/correction → verified report. A synthetic demo PDF exercises the same path.
* Deterministic metrics, data-sufficiency checks (14 days / 70 %), consistency checks, episode detection for raw readings.
* Versioned, documented **demo** rule set with the four allowed outcomes.
* Manual lab entry, HbA1c unit handling, **GMI vs HbA1c** with date alignment, HbA1c/lab/CGM-period trends.
* Clinician-provided/user-confirmed lab reminders linked to a simulated appointment.
* Visit-preparation summary with neutral questions and **PDF export**.
* Follow-up request → demo reviewer dashboard → decision visible to the patient; automation via a labelled local mock.
* Bounded assistant: explains verified data with local templates, refuses dosing, general safety message for urgent concerns.

Live (optional): Supabase Auth + Postgres with RLS and workflow RPCs, Gemini via Edge Functions (validated, guarded, with fallback), Make.com via a backend webhook with retries and idempotency. See [docs/SETUP_WINDOWS.md](docs/SETUP_WINDOWS.md).

## Quick start (Windows, demo mode)

Requirements: Flutter **3.47.8** stable (Dart 3.13), Git, and either Visual Studio 2022 (Desktop C++) or Android Studio with an emulator. Enable Windows Developer Mode.

```powershell
git clone https://github.com/enghanamansour/sukkar_plus.git
cd sukkar_plus\app
flutter create . --platforms=android,windows --project-name sukkar_plus --org sa.sukkarplus
flutter pub get
flutter run -d windows
```

Or run `powershell -ExecutionPolicy Bypass -File tool\setup_windows.ps1` to run all checks first. The three-minute walkthrough is in [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md).

## Repository layout

| Path | Contents |
|------|----------|
| `packages/sukkar_core/` | Pure-Dart domain logic and 143 tests |
| `app/` | Flutter app (`lib/`, fonts, tests, `dart_defines.example.json`) |
| `supabase/` | migrations (schema, RLS, RPCs), Edge Functions, PGlite tests, synthetic seed |
| `make/` | Make.com scenario guide and example payload |
| `docs/` | architecture, metrics, lab methodology, source mapping, privacy, design, setup, demo, test report |
| `tool/` | Windows scripts, offline test runner |

## Documentation

* [Architecture](docs/ARCHITECTURE.md)
* [Metric definitions](docs/METRICS.md) · [Lab comparison methodology](docs/LAB_COMPARISON_METHODOLOGY.md) · [Supported PDF format](docs/PDF_REPORT_FORMAT.md)
* [Source mapping](docs/SOURCE_MAPPING.md) — every threshold and rule, sourced or marked demo-only
* [Privacy and limitations](docs/PRIVACY_AND_LIMITATIONS.md)
* [Design system](docs/DESIGN_SYSTEM.md)
* [Setup, Supabase, Gemini, Make.com](docs/SETUP_WINDOWS.md) · [Make.com](make/README.md)
* [Test report](docs/TEST_REPORT.md) — what was actually executed, and what was not

## Data and licences

All bundled data is synthetic. The real report and the AZT1D dataset used during development are **not** included. IBM Plex Sans Arabic is bundled under the SIL Open Font License (`app/assets/fonts/OFL.txt`).
