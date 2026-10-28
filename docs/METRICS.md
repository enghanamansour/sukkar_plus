# Metric definitions and calculation policy

All numbers are computed by deterministic code in `packages/sukkar_core`. The AI is never asked to calculate percentages or to judge whether numbers are consistent. Sources for every threshold are in [SOURCE_MAPPING.md](SOURCE_MAPPING.md).

## Two kinds of reports

| | Printed summary (PDF upload) | Raw readings (demo series, CSV import) |
|---|---|---|
| Values | Read from the printed page, then confirmed by the user | Calculated from timestamped readings |
| Origin label | `مستخرج من التقرير` / `مصحّح يدويًا` | `محسوب من القراءات` |
| Time series | **Not reconstructed.** The app never invents readings from a summary. | Available |
| Episode rule | Not applicable (stated in the UI) | Evaluated |

Derived metrics (`محسوب من مؤشرات موثّقة`) are computed only from **verified** values: total TBR = very low + low, total TAR = high + very high, and GMI from verified mean glucose when the report prints no GMI. A derived value never overwrites a printed one.

## Metrics

| Key | Definition | Unit |
|-----|-----------|------|
| `mean_glucose` | arithmetic mean of valid readings | mg/dL (mmol/L reports are converted ×18.0182) |
| `gmi` | 3.31 + 0.02392 × mean (mg/dL) | % |
| `sd` | sample standard deviation (n − 1) | mg/dL |
| `cv` | SD ÷ mean × 100 | % |
| `time_very_low` | readings < 54 | % of readings |
| `time_low` | 54 ≤ x < 70 | % |
| `time_in_range` | 70 ≤ x ≤ 180 | % |
| `time_high` | 180 < x ≤ 250 | % |
| `time_very_high` | x > 250 | % |
| `time_below_range_total` / `time_above_range_total` | < 70 / > 180 | % |
| `sensor_active` | printed "Connected Sensor Time"/"% time CGM active", or computed coverage | % |

## Raw-reading policy (`CgmCalculator`)

* **Sampling assumption:** 5-minute interval (configurable `expectedIntervalMinutes`). Matches the AZT1D files and Dexcom G7.
* **Validity:** readings outside 20–600 mg/dL, NaN or infinite are excluded and counted (`invalidReadings`). Note: sensors print floors/ceilings (e.g. 40 mg/dL in AZT1D); those are kept as recorded.
* **Timestamps:** treated as local wall-clock time without time zone (AZT1D `EventDateTime`). Readings are stably sorted by time.
* **Duplicates:** same timestamp and same value → dropped (`duplicateReadings`). Same timestamp, different value → the first in input order is kept and the conflict is counted (`conflictingDuplicates`) and shown as a data-quality note. (In the 25 AZT1D files, 5,288 exact duplicates and 501 conflicts were found and handled this way.)
* **Weighting:** percentages are count-based (each reading has equal weight). With regular sampling this approximates time-weighting; gaps are *not* filled.
* **Window:** the report period (inclusive calendar days) or, without one, first-to-last reading.
* **Coverage:** unique valid readings ÷ (window minutes ÷ interval), capped at 100 %.
* **Gaps:** an interval between consecutive readings > 2 × interval; count and longest gap are reported.
* **Missing values** are `null` with status `unavailable` — never 0. The database enforces this with a CHECK constraint.

## Data sufficiency

`sufficient = days ≥ 14 AND coverage ≥ 70 %` (S1). For printed reports the coverage comes from the printed percentage, labelled "as printed — the report does not state the denominator". If coverage is not printed, the report is **insufficient** ("we cannot assess coverage"), never assumed sufficient.

For Omnipod Discover reports the *metrics period* is the printed "sensor data is only available from … – …" window, which can be much shorter than the report header period (the supplied 90-day report had a 56-day sensor window).

## Episodes

Runs of consecutive readings below the threshold; duration = last − first + interval. Runs separated by fewer than 15 minutes of readings at/above the threshold merge; runs are never joined across a data gap. An episode counts if one of its runs lasted ≥ 15 minutes. This approximates the 2017 consensus episode definition referenced in S1 Table 1.

## Printed-summary consistency checks (`runSummaryChecks`)

| Check | Rule | Tolerance |
|-------|------|-----------|
| `band_sum` | five bands ≈ 100 % | ± 2.0 |
| `tbr_total`, `tar_total` | printed totals = sum of their two bands | ± 1.0 |
| `triple_sum` | TBR + TIR + TAR ≈ 100 % | ± 2.0 |
| `gmi_mean` | printed GMI vs GMI formula from printed mean | ± 0.15 |
| `cv_sd_mean` | printed CV vs SD ÷ mean | ± 1.0 |

A failed check marks the involved fields "غير متسق" and removes them from bulk confirmation; a missing value makes a check "not evaluable", never "passed". On the supplied real report all six checks pass.
