# Adeed (عضيد) — Arabic-first diabetes report assistant

Adeed helps a person with diabetes **understand their own diabetes reports**, **prepare for medical appointments**, and **ask everyday diabetes questions** — in Arabic (RTL) by default, with English support.

> **Independent prototype.** Adeed is *not* part of, integrated with, or endorsed by Sehhaty (صحتي) or the Saudi Ministry of Health. It is educational, does not diagnose, prescribe, set insulin doses or change device settings, and never replaces medical care. In an emergency call **997**.

It ships inside a Sehhaty-*inspired* mobile shell (the supplied mockup). Adeed is mounted at `/my-profile/diabetes-journey/*` through the shell's documented integration point (`src/components/diabetes-integration/mount.ts`, Option A).

---

## What's in the app

| Area | What it does |
|---|---|
| **Accounts** | Email + password sign-up / sign-in / password reset (Supabase Auth). Each user sees only their own data (Postgres RLS + private storage). |
| **Dashboard** | Latest report with time-in-ranges chart, key numbers, comparison with the previous *compatible* report, processing/failed states, empty state with upload and demo data. |
| **Report upload & processing** | PDF upload (≤10 MB) to a private bucket → server-side text extraction (`unpdf`) → metric parser → validation → stored metrics → doctor questions. |
| **Report detail** | Every metric with value, unit, **status** (extracted / calculated / unavailable / uncertain), source page and matched text; data-quality checks; HbA1c (lab) shown *separately* from GMI; comparison table; device settings (information only). |
| **History** | All CGM reports over time with range bars; compatibility labels; HbA1c lab entries (add/delete). |
| **Doctor questions** | 3–8 questions per report generated from real findings, comparisons and data gaps. Each shows *why it matters*, the *evidence* (metric, value, page, previous report, lab) and an *uncertain* flag. Edit, save, copy, delete, add your own. |
| **Appointment preparation** | Date / clinic / notes + a printable, copyable summary: findings vs. general targets, comparison, data gaps, HbA1c, questions. |
| **Assistant (one persistent chat)** | Groq (primary) → Gemini (automatic fallback). Server-side tools read only the signed-in patient's data via RLS; deterministic emergency + dose-request safety layer works even with no AI key. History is stored per user and can be cleared. |
| **Settings** | Name, diabetes type, demo data load/remove, delete all my data, sign out. |

### Extraction rules (no fabrication)
- Values are recorded only if found, with **source page** and **matched text**.
- Totals (time below/above range) are marked **calculated**.
- Expected metrics that are missing are stored as **unavailable** (e.g. *CGM active time* in the supplied samples — the pump's "Automated Mode" % is **not** substituted).
- Consistency checks downgrade values to **uncertain**: ranges must sum to ~100%, GMI must match `3.31 + 0.02392 × mean`, CV must match `SD ÷ mean`. *(3 of the 4 supplied sample profiles print a CV that contradicts their own SD and mean — Adeed flags it instead of trusting it.)*
- **HbA1c ≠ GMI.** HbA1c comes only from lab results (manual entry or a lab PDF); "estimated A1C" text is never treated as HbA1c.
- **Comparisons** only between CGM reports with known, non-overlapping periods, the same target range, both real (or both demo), and similar length; otherwise "limited" (with reason) or refused. No trend is ever drawn from one report.

---

## Architecture

```
Browser (React 18 + Vite, RTL)            Supabase (project ref bmoblgikggxaidntdakx, eu-central-1)
 ├─ src/ (Sehhaty-inspired shell)          ├─ Postgres: profiles, reports, report_metrics, lab_results,
 └─ src/adeed/ (feature)                   │            doctor_questions, chat_messages   — all with RLS
      │  publishable key + user JWT        ├─ Storage: private bucket "reports" (PDF only, 10 MB, per-user folders)
      ├──────────────── REST / Storage ───▶├─ Edge Function process-report  (unpdf → parser → metrics → questions)
      └──────────────── functions.invoke ─▶└─ Edge Function chat  ──▶ Groq ──(fails)──▶ Gemini
                                                 tools run as the user (RLS), never raw SQL
supabase/functions/_shared/core/  ← one dependency-free TypeScript module shared by both functions AND the browser:
   catalog.ts (metrics, targets) · parser.ts · compare.ts · questions.ts · safety.ts
```

Secrets: only the **publishable** key is in the browser. `GROQ_API_KEY` / `GEMINI_API_KEY` exist only as Edge Function secrets; the service/secret key is never in the repo or bundle.

---

## Current deployment status (verified 2026-10-29)

| Item | Status |
|---|---|
| Supabase project `adeed` (org *Tuwaiq*, eu-central-1) | ✅ created |
| Schema, RLS, triggers, private bucket + storage policies (`supabase/migrations/*`) | ✅ applied via the Supabase connector; security advisor clean except "leaked password protection" (dashboard toggle, see below) |
| Edge Functions `process-report` (v1) and `chat` (v2, Groq→Gemini) | ✅ deployed, `verify_jwt=false` (functions verify the session themselves) |
| `GROQ_API_KEY` / `GEMINI_API_KEY` secrets | ❌ **not set** — the connector's secret flow was paused. Chat returns `ai_not_configured` until you add one (steps below). Everything else works without it. |
| Frontend hosting | Not deployed (no hosting connector available here). Run locally or deploy with the steps below. |

---

## Setup

### 1. Activate the assistant — add the AI key (one manual step)
1. Open **Supabase Dashboard → Project `adeed` → Edge Functions → Secrets** (`https://supabase.com/dashboard/project/bmoblgikggxaidntdakx/functions/secrets`).
2. Add **`GROQ_API_KEY`** = your key from https://console.groq.com/keys → **Save**.
3. *(Recommended)* Add **`GEMINI_API_KEY`** = your key from https://aistudio.google.com/apikey — used automatically if Groq fails or rate-limits.
4. Optional overrides: `GROQ_MODEL` (default `openai/gpt-oss-120b`), `GEMINI_MODEL` (default `gemini-3.8-flash`), `ALLOWED_ORIGIN` (restrict CORS to your site's origin).
5. No redeploy needed. Verify: sign in → **المساعد** → ask "اشرح لي تقريري الأخير". The reply is stored with `flags.provider = "groq"` (or `"gemini"` when the fallback was used).

CLI alternative: `supabase secrets set GROQ_API_KEY=... GEMINI_API_KEY=... --project-ref bmoblgikggxaidntdakx`

### 2. Auth settings (Dashboard → Authentication)
- **URL Configuration:** set *Site URL* to where the app runs (e.g. `http://localhost:5173` for development, your production URL later) and add `http://localhost:5173/**` and your production URL to *Redirect URLs* — confirmation and reset links use them.
- **Email:** Supabase's built-in email sender only delivers to your organisation's team members and is rate-limited. For other users, configure **custom SMTP** (Authentication → Emails → SMTP), or for a closed pilot disable *Confirm email*.
- **Security:** enable *Leaked password protection* (Authentication → Policies/Passwords).

### 3. Run locally
Requirements: Node 18+ (tested on Node 22).
```bash
npm install
cp .env.example .env.local      # contains the project URL + publishable key (browser-safe)
npm run dev                     # http://localhost:5173  → ملفي → عضيد  (or open /my-profile/diabetes-journey)
```
Try it: create an account → upload any PDF from `fixtures/sample-reports/`, or press **"جرّب ببيانات تجريبية"** to load the synthetic demo set (3 reports + 1 HbA1c, all labelled demo).

### 4. Deploy the frontend (static)
```bash
npm run build                   # → dist/
```
Host `dist/` on any static host (Vercel, Netlify, Cloudflare Pages, Supabase-adjacent hosting…) with an **SPA fallback to `index.html`**, and set `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` in the host's build environment. Then add the production URL to Auth *Site URL / Redirect URLs* and (optionally) `ALLOWED_ORIGIN`.

### 5. Re-deploying the backend yourself (Supabase CLI)
```bash
supabase link --project-ref bmoblgikggxaidntdakx
supabase db push                                   # applies supabase/migrations/*
supabase functions deploy process-report --no-verify-jwt
supabase functions deploy chat --no-verify-jwt
```
To use a **new** Supabase project instead: create it, run the three migrations, deploy both functions, set the secrets, and put the new URL + publishable key in `.env.local`.

---

## Tests and what was verified

```bash
npm test            # 42 unit tests (Vitest)
npm run typecheck   # TypeScript, strict
npm run build
npm run dev & npm run test:ui     # Playwright UI walkthrough (mocked API; fixtures from the real parser)
```

| Check | Result |
|---|---|
| Parser vs. **all 20 supplied PDFs** (`fixtures/sample-reports`) — every range %, mean, GMI, CV, SD, dates, device, page numbers, settings | ✅ exact match to the generator's ground truth |
| CV inconsistency detection (profiles 1–3), GMI consistency, range sums, missing CGM-active time, HbA1c never taken from GMI/"estimated A1C", scanned/unrelated PDFs rejected, inline/ISO/lab formats | ✅ |
| Comparison rules (overlap, demo vs real, different lengths → limited, unit mismatch) and question generation (3–8, evidence, uncertainty, maintenance case) | ✅ |
| Safety detection (Arabic/English emergencies, urgent symptoms, dose requests) | ✅ |
| Same parser running under **Deno** with `unpdf` on a real sample PDF | ✅ |
| **Live** (deployed project, via `tests/live/*.sql`): sign-in → private upload → report row via RLS → `process-report` extracted 11 metrics + 4 questions in the Edge runtime → chat emergency notice and dose notice without an AI key → unauthenticated call rejected (401) | ✅ |
| **Live isolation:** another user cannot list/read reports, metrics or questions, process the report, download the file, write into the folder, insert as the other user, forge a "processed" report; anonymous reads denied; bucket not public | ✅ 10/10 blocked |
| UI walkthrough: sign-in, dashboard, report detail + table view, questions, history, appointment, chat emergency path — Arabic RTL mobile, English LTR **dark**, desktop width; no console errors, no horizontal overflow | ✅ |
| Groq / Gemini answers | ⏳ **not yet testable** — no key configured. The integration is built; verify with step 1 above. |
| Upload of the image-bearing sample PDFs through the live Edge Function | Not run live (this build environment can't reach supabase.co directly); the same code path ran live with a text PDF and locally under Deno with the real samples. |

---

## Data & fixtures (synthetic only)
- `fixtures/sample-reports/` — the 20 supplied synthetic AGP PDFs; `fixtures/labs/` — supplied HbA1c spreadsheets; `fixtures/reference/` — ATTD 2019 consensus and ADA Standards 2026 introduction (used for targets/wording).
- `fixtures/demo/` + `public/demo/` — demo persona: supplied `report_patient_3.pdf` (Aug 2026) plus two **generated** earlier reports (`fixtures/generate_demo_history.py`, same layout: June 30-day, July 14-day). Demo HbA1c 7.4 % on 2026-08-02 is the spreadsheet row for patient 3.
- Demo data is loaded only into the signed-in user's own account, always `is_demo = true`, labelled everywhere, and never compared with real data. No production logic contains fixture values.

## Charts
Time-in-range colours were validated for colour-vision-deficiency separation in light and dark mode; values are always direct-labelled and a table view is one tap away.

## Repository map
```
src/adeed/            Adeed feature (pages, components, context, api, strings ar/en, styles)
src/                  Sehhaty-inspired shell (see docs/SHELL_README.md, FRONTEND_HANDOFF.md)
supabase/migrations/  SQL schema, RLS, storage
supabase/functions/   process-report, chat, _shared/server.ts, _shared/core/*
tests/                unit tests, e2e UI walkthrough, live SQL checks
fixtures/             synthetic sample data and generators
```

## Housekeeping on the live project
Two synthetic QA accounts (`qa.patient.a/b@adeed-test.dev`) and the `http` extension remain from live testing. Run `tests/live/99_cleanup.sql` in the SQL editor to remove them.
