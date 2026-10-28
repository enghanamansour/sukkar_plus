# Supported report format

## Verified layout: `omnipod_discover_agp_summary_v1`

The **summary page** ("N-Day Summary") of the **Omnipod Discover** HCP report for **Omnipod 5 with Dexcom G7**, exported as a text PDF. The parser was developed against the text PDFium produces for the real report supplied for this project (the app uses PDFium on the device via `pdfrx`). No value or identifier from that report is stored in this repository; tests use a synthetic report rendered in the same layout (`packages/sukkar_core/test/fixtures/`).

| Field | How it is found |
|-------|----------------|
| Report period | line `DD/MM/YYYY–DD/MM/YYYY | Report Generated: …`; day/month order confirmed against "N-Day Summary" |
| Metrics period | `Sensor data is only available from DD/MM/YYYY–DD/MM/YYYY` (falls back to the report period) |
| Average glucose, SD | line after `Average Glucose` / `Standard Deviation (SD)` (`126 mg/dL`) |
| GMI, CV | line after `Glucose Mgmt Indicator (GMI)` / `Glucose Variability (CV*)` |
| Coverage | `Connected Sensor Time NN%` |
| Range bands | `2% Very Low`, `3.4% Low`, `10.3% High`, `1.5% Very High` |
| TIR, TBR total, TAR total | unlabelled row `5.4% 82.8% 11.8%`, accepted only if it reconciles with the bands (± 1 %) and sums to ~100 % |
| Device label | `Device Use | Omnipod® 5 & Dexcom G7` |
| Notices | "Report has limited or no data for some days" → data-quality warning |

Deliberately **not read**: patient name, date of birth, serial numbers, insulin totals, bolus/basal data, carbohydrates, pump settings (page 20), daily charts (pages 2–19 contain no glucose values in text form).

Lines such as `Goal: <4%` never match because the parser works line by line on exact shapes.

## Unverified fallback: `generic_agp_unverified`

Best-effort label search for other AGP-style reports (Dexcom Clarity, LibreView, mmol/L reports). Never verified against a real file: every value is marked "لم يُتحقق منه آليًا" and must be confirmed individually; ambiguous slash dates (both parts ≤ 12) are flagged.

## Rejected inputs (Arabic messages in `pdf_validation.dart`)

Wrong extension, empty file, > 15 MB, missing `%PDF-` header, truncated file (no `%%EOF`), encrypted PDF, PDF without extractable text (scanned images), and PDFs with no recognisable CGM metric.

## Optional AI cross-check

With consent and a configured backend, the `extract-report` Edge Function asks Gemini for the same fields as JSON. The response is validated on the server and again on the device (types, units, ranges, duplicates, unknown keys), then reconciled field by field with the local result: agreement keeps a field eligible for "confirm all"; disagreement or AI-only values require individual confirmation.
