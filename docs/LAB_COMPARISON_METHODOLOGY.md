# Laboratory comparison methodology

## Principles

1. **Manual, user-verified entry is the primary path.** Saving the form is the user's confirmation that value, unit and date match the laboratory report.
2. **Dates are required for time-based comparisons.** Undated results are stored and listed but excluded from trends and from GMI comparisons, with an explanation.
3. **Units stay explicit.** Only HbA1c has a conversion (% ↔ mmol/mol, IFCC–NGSP master equation). Other tests are compared only when recorded in the same unit.
4. **No interpretation of other tests.** LDL, eGFR, creatinine, UACR, fasting glucose and free-text tests are shown with the laboratory's own reference interval, copied by the user and labelled "مرجع المختبر" — explicitly not a treatment target.
5. **No causal language.** Every trend view carries "التغيّر عبر الزمن لا يدل وحده على سبب محدد".

## HbA1c validation

* Unit must be `%` or `mmol/mol` (also enforced by a database CHECK).
* Plausibility bounds catch unit mix-ups: 3–20 % or 9–195 mmol/mol (e.g. "54 %" is rejected with "check the unit").
* Collection date cannot be in the future.

## GMI versus HbA1c

| Step | Rule |
|------|------|
| Pick values | Latest verified, dated HbA1c; the CGM report whose metrics period starts on/before that date (user can choose others in the screen). GMI must be verified (printed, user-corrected, or computed from verified mean). |
| Convert | HbA1c in mmol/mol → % for the comparison only; flagged "محوّل". |
| Align | **Aligned** if the sample was collected during the CGM metrics period or within **30 days after** it ends (configurable `GmiHbA1cConfig.maxDaysAfterPeriodEnd`). This is a display convention, not a clinical rule. |
| Difference | Shown as HbA1c − GMI in percentage points **only when aligned**. Otherwise both values are shown side by side with a neutral note explaining why no difference is shown. |
| Caveats | Insufficient CGM data (< 14 days or < 70 %) adds a note that GMI may not represent the period. |
| Wording | GMI = estimate from the CGM period; HbA1c = laboratory blood test reflecting preceding weeks to months. "The two are not interchangeable; a difference alone does not mean a diagnosis or a specific cause." No value is ever called dangerous, abnormal or significant. |

## Historical trends

* **HbA1c:** chronological, verified and dated results in %; latest vs previous: delta, direction (ارتفاع / انخفاض / دون تغيّر — never "better/worse"), days between.
* **Other tests:** same-unit only; mixed units → "no numeric comparison without an approved conversion".
* **CGM periods:** the two most recent reports with known periods; overlapping periods are not compared; only metrics verified in both are compared; differing lengths (> 2×) and insufficient data are flagged; the gap between periods is reported as a missing period.

## Reminders

Reminders are created only from a **clinician-provided** or **user-confirmed** schedule (the source is stored and shown). The app never infers that a test is due from a diabetes diagnosis. The only general prompt is: "اسأل فريقك الصحي عن التحاليل المطلوبة قبل موعدك القادم، إن وُجدت. التطبيق لا يحدد جدول التحاليل." States: upcoming / overdue (derived from dates) / completed / cancelled; completing a reminder can record the collection date and link the entered result.
