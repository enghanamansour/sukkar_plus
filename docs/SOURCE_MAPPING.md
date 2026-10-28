# Source mapping

Every clinical number, metric definition and rule used by Sukkar Plus, mapped to its source — or explicitly marked as a **demonstration-only** choice that requires clinical review before any real use.

Supplied files (read for this project):

| ID | File | What it is |
|----|------|-----------|
| **S1** | `dci190028.pdf` | Battelino T, et al. *Clinical Targets for Continuous Glucose Monitoring Data Interpretation: Recommendations From the International Consensus on Time in Range.* Diabetes Care 2019;42:1593–1603. doi:10.2337/dci19-0028 |
| **S2** | `dc26sint.pdf` | *Introduction and Methodology: Standards of Care in Diabetes—2026* (ADA). **Methodology only** — evidence-grading system, committee process. It contains **no CGM or laboratory thresholds**, and none are attributed to it. |
| **S3** | `Discover_Web_HCP.pdf` | A real Omnipod Discover HCP report (Omnipod 5 + Dexcom G7). Used only to learn the page layout. **No values or identifiers from it are stored in this repository.** |
| **S4** | `CGM_Records.zip` | AZT1D CGM records (25 subject CSV files). Used only to validate the CSV importer locally. **Not bundled.** Licence/terms not confirmed from supplied documentation. |

External sources (not supplied; cited because a supplied source refers to them):

| ID | Source |
|----|--------|
| **E1** | Bergenstal RM, et al. *Glucose Management Indicator (GMI): a new term for estimating A1C from continuous glucose monitoring.* Diabetes Care 2018;41:2275–2280. (Reference 75 of S1.) |
| **E2** | Hoelzel W, et al. *IFCC reference system for measurement of hemoglobin A1c in human blood and the national standardization schemes in the United States, Japan, and Sweden: a method-comparison study.* Clin Chem 2004;50:166–174 (IFCC–NGSP master equation). |

> Status column: **Sourced** = number/definition taken from the cited source. **Demo** = design choice for the prototype; configurable; must be reviewed by clinicians before real use.

## CGM metric definitions

| Item | Value used in code | Source | Status | Code |
|------|-------------------|--------|--------|------|
| Glucose ranges | very low < 54; low 54–69; in range 70–180; high 181–250; very high > 250 mg/dL (3.0 / 3.9 / 10.0 / 13.9 mmol/L) | S1 Table 2 | Sourced | `cgm/metrics_calculator.dart`, `models/cgm.dart` |
| Continuous-value boundaries | < 54; 54 ≤ x < 70; 70 ≤ x ≤ 180; 180 < x ≤ 250; > 250 | S1 prints integer ranges; extension to non-integers is ours | Demo (implementation detail) | `CgmCalculator` |
| Data sufficiency | ≥ 14 days and ≥ 70 % of possible readings | S1 Table 2 items 1–2; text p. 1595 | Sourced | `DataQuality.minDays/minCoveragePercent` |
| %CV target | ≤ 36 % (S1 notes < 33 % may add protection for some) | S1 Table 2 item 5 | Sourced | `targets.dart` |
| GMI formula | GMI (%) = 3.31 + 0.02392 × mean (mg/dL); GMI (mmol/mol) = 12.71 + 4.70587 × mean (mmol/L) | E1 (cited by S1 ref. 75; formula not printed in S1) | Sourced (external) | `cgm/gmi.dart` |
| GMI ↔ printed mean consistency tolerance | ± 0.15 percentage points | Rounding allowance | Demo | `Gmi.consistencyTolerancePercent` |
| Band-sum tolerance for printed summaries | ± 2.0 % (TBR/TAR totals vs bands ± 1.0 %) | Rounding allowance | Demo | `SummaryTolerances` |
| mg/dL ↔ mmol/L | 1 mmol/L = 18.0182 mg/dL | Molar mass of glucose | Sourced (chemistry) | `common/units.dart` |
| Episode minimum duration | ≥ 15 minutes | S1 Table 1 item 12 (2017 consensus metrics) | Sourced | `CgmCalculator.detectEpisodesBelow` |
| Episode start/end merging | runs separated by < 15 min above threshold are merged; never across data gaps > 2 × interval | Approximation of the 2017 consensus definition referenced by S1 | Demo (approximation) | same |
| SD | sample SD (n − 1) | S1 does not specify | Demo | `CgmCalculator` |

## General reference targets (displayed only for the selected population)

| Profile | Targets | Source | Status |
|---------|---------|--------|--------|
| Adults with T1/T2 diabetes | TIR > 70 %; TBR < 70 mg/dL < 4 %; < 54 mg/dL < 1 %; TAR > 180 < 25 %; > 250 < 5 % | S1 Table 3 | Sourced |
| Older / high-risk adults | TIR > 50 %; TBR < 70 mg/dL < 1 %; > 250 mg/dL < 10 % | S1 Table 3 | Sourced |
| Age < 25 with A1C goal 7.5 % | TIR target ≈ 60 % — shown as a note, not applied automatically | S1 Table 3 footnote | Sourced (note only) |
| Pregnancy | Different ranges (63–140 mg/dL); **not implemented** — app shows "targets come from your care team" | S1 Table 4 | Not applied |
| Pediatric / unspecified | No targets applied | — | Not applied |

S1 states these are general targets that must be personalised; the app labels them "أهداف مرجعية عامة" and never infers a user's population.

## Follow-up review rules (rule set `2026.10-demo.1`)

All rules are **demonstration-only**. Their thresholds reuse sourced reference targets, but **using a target exceedance to trigger a human-review task is not a validated clinical triage criterion**. None of them assesses emergencies.

| Rule | Logic | Threshold source | Window / data-quality gate | Status |
|------|-------|-----------------|----------------------------|--------|
| `TBR54-TARGET` v1 | time < 54 mg/dL does not meet the profile target | S1 Table 3 | report metrics period; ≥ 14 d & ≥ 70 % coverage | Demo |
| `TBR70-TARGET` v1 | total time < 70 mg/dL does not meet the profile target | S1 Table 3 | same | Demo |
| `TAR250-TARGET` v1 | time > 250 mg/dL does not meet the profile target | S1 Table 3 | same | Demo |
| `EPI54-REPEATED` v1 | ≥ **2** episodes < 54 mg/dL lasting ≥ 15 min in the last 14 days of raw readings | duration: S1 Table 1; **count of 2: invented for the demo** | requires timestamped readings; ≥ 14 d & ≥ 70 % | Demo |

Outcome precedence: any triggered rule → "يُقترح طلب مراجعة بشرية"; otherwise any rule not assessable or insufficient data → "نحتاج بيانات إضافية"; otherwise "ملخص روتيني" (explicitly *not* a statement of safety). "يرجى طلب المساعدة الطبية المناسبة" is shown only when the user reports an urgent concern; it is general safety messaging (emergency numbers 911 / 997 in Saudi Arabia) and never an assessment.

S1 notes that ~4 weeks of data may be needed to investigate hypoglycaemia exposure; the episode rule's 14-day window is therefore a limitation (documented in the rule).

## Laboratory comparison

| Item | Value | Source | Status |
|------|-------|--------|--------|
| HbA1c % ↔ mmol/mol | NGSP = 0.09148 × IFCC + 2.152 | E2 | Sourced (external) |
| HbA1c plausibility bounds | 3–20 % or 9–195 mmol/mol (entry validation only) | — | Demo |
| GMI vs HbA1c "aligned" window | lab sample during the CGM period or ≤ 30 days after it | Display methodology; S1 discusses GMI/A1C discrepancies (p. 1600) but defines no window | Demo, configurable (`GmiHbA1cConfig`) |
| Difference shown | HbA1c (%) − GMI (%) only when aligned; never labelled abnormal or significant | — | Design rule |
| Other lab tests | Shown as entered with the laboratory's own reference interval; **no interpretation** | — | Design rule |
| Testing schedules | None invented; reminders only from clinician-provided or user-confirmed schedules | — | Design rule |

## Report parsing (layout facts from S3)

| Fact | Used for |
|------|----------|
| Page 1 is "N-Day Summary"; dates printed DD/MM/YYYY | Period parsing; day/month order confirmed by matching N |
| Bands printed as "2% Very Low", "3.4% Low", …; TIR printed unlabelled in a row "5.4% 82.8% 11.8%" | TIR accepted only when the row reconciles with the band values |
| "Sensor data is only available from … – …" | Becomes the **metrics period** (differs from the report period) |
| "Connected Sensor Time NN%" | Coverage, labelled "as printed — denominator not stated" |
| Pages 2–19 daily charts; page 20 pump settings | Ignored (no glucose series in text; no dosing data used) |
