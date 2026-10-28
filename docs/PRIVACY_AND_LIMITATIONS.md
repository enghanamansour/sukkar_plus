# Privacy, security and limitations

Sukkar Plus is an **independent concept prototype** for an innovation demonstration. It is not affiliated with Sehhaty, the Ministry of Health, Insulet, Dexcom or any provider, and it does not claim compliance with any healthcare regulation or security standard.

## What is processed, where

| Data | Demo mode | Live mode |
|------|-----------|-----------|
| Uploaded PDF | Read on the device (PDFium); kept in memory only until the review is accepted or discarded | Same; **never uploaded to storage** (`storage_path` stays null) |
| PDF sent to AI | Never | Only if the user ticked the separate external-AI consent **and** the server has `GEMINI_API_KEY`; sent once via the Edge Function, not stored |
| Confirmed metrics, labs, reminders | Device memory (cleared on restart) | Supabase Postgres, owner-only RLS |
| Name | Synthetic demo name | `patient_identities` table, separate from analytic tables |
| Shared with reviewer | Snapshot the patient reviewed: verified metrics of one report, its period, data-quality notes, pseudonymous request ID | Same |
| Sent to Make.com | Nothing (local mock) | `request_ref` (pseudonym), status, trigger type, rule IDs, rules version, timestamp, environment. No names, IDs, values, labs or PDFs |
| Logs | No medical values | Edge Functions log event names and counts only |

## Controls implemented

* Informed consent before processing any real report; demo exploration never claims consent.
* Separate opt-in for sending a PDF to an external AI provider, disclosed in Arabic.
* File type, size (15 MB), structure, encryption and text checks before parsing.
* Secrets only in Supabase Edge Function secrets; the app ships only the public Supabase URL and publishable key.
* Row Level Security on every table; role stored server-side and not updatable by users; reviewer access through column-restricted grants; workflow changes only through RPCs; `anon` has no access.
* Deletion: "حذف جميع بياناتي" (RPC `delete_my_data`) and consent withdrawal.
* AI text is checked for dosing/diagnostic language and for numbers not present in the verified data; on failure the local template is used and the user is told.

## Clinical limitations

* No diagnosis, emergency triage, or treatment/dose advice. The urgent-concern path shows general safety messaging only.
* All review-trigger rules are **demonstration rules** (see SOURCE_MAPPING.md). "ملخص روتيني" is never a statement of safety.
* General consensus targets are population-level and shown only for the population the user selects; pregnancy and paediatric targets are not applied.
* Printed PDF summaries cannot support episode or pattern-timing analysis; the app says so instead of reconstructing data.
* The Omnipod Discover layout is the only verified format; other formats are best-effort and require per-value confirmation.
* GMI–HbA1c alignment window (30 days) is a display convention.
* The demo reviewer is not a clinician; requests are not sent to any healthcare provider and no appointment is created.

## Data used to build and test

* **Synthetic** data only in the repository (demo seed, synthetic report layout, synthetic CSV rows).
* The real Omnipod report supplied by the user was used locally to verify the parser's layout handling and is **not** included. Personal details on it (name, date of birth, device serial) were never written to any project file.
* The AZT1D files were used locally to validate the CSV importer and are **not** included; check the dataset's licence before redistributing anything derived from it.

## Gemini and Make.com terms

Before sending any real health data to Gemini, review Google's current Gemini API terms for your account tier (data-use terms differ between unpaid and paid usage). The default configuration sends nothing. For Make.com, enable API-key authentication on the webhook and, if possible, an IP allowlist.
