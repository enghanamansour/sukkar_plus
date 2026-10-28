# Three-minute demo script

Demo mode, synthetic data. The banner "وضع العرض — بيانات تجريبية" stays visible throughout. Restart the app (or Profile → "إعادة ضبط بيانات العرض") before each run.

| Time | Screen | Do | Say |
|------|--------|----|-----|
| 0:00 | Welcome | Tap **استكشاف البيانات التجريبية دون موافقة** | Independent prototype; no diagnosis, no doses, no real providers. |
| 0:10 | Home | Point at the taupe card and **ملخصي الصحي** | A clinician-requested HbA1c is due before the (simulated) appointment. Every value carries its origin. |
| 0:25 | Upload | **رفع تقرير جديد** → **استخدم تقريرًا تجريبيًا** | A real PDF is generated and read on the device with PDFium, exactly like a user's file. |
| 0:40 | Review | Show the six passing checks → **تأكيد كل القيم التي اجتازت التحقق** → **اعتماد القيم وعرض التحليل** | Nothing is used until confirmed; corrections keep the original value. |
| 1:00 | Analysis | Outcome **يُقترح طلب مراجعة بشرية**; open **تفاصيل القواعد المطبقة** | Three demo rules use published reference targets; each shows window, data-quality gate, source and its demo status. |
| 1:15 | GMI vs HbA1c | **GMI مقابل HbA1c**, then switch **تقرير الحساس** to the new upload | By default the latest HbA1c (6 weeks old) is paired with the CGM period it follows → aligned, small difference. Against the new upload it is "not aligned" and no difference is shown. |
| 1:30 | Reminders | Back → Home → **التحاليل الدورية** → HbA1c → **تم — أدخل النتيجة** → value 7.2 %, today → save | Completing a clinician-provided reminder records the result. |
| 1:50 | GMI vs HbA1c | Reopen comparison | Now aligned (1 day after the CGM period) → difference with neutral explanation. |
| 2:00 | Follow-up | Home → summary → **طلب مراجعة بشرية (محاكاة)** → tick → **تأكيد إرسال الطلب** | Only the snapshot shown is shared, with a pseudonymous ID; automation event recorded by the mock. |
| 2:20 | Reviewer | Profile tab → **التبديل إلى المراجع التجريبي** → open the new request → **بدء المراجعة** → **مراجعة مطلوبة** + note → save | Demo reviewer, not a clinician; sees only the snapshot. |
| 2:40 | Patient | **العودة إلى واجهة المستخدم** → Home → **طلبات المراجعة** → request | Status "تمت المراجعة" and the reviewer note are visible. |
| 2:50 | Visit prep | Tab **موعدي** → scroll → **تصدير الملخص PDF** | Dated, sourced summary with missing data, reminders and neutral questions. |

Backup lines if asked:

* *Real report?* The parser was checked against the supplied Omnipod Discover PDF: 12/12 fields, all arithmetic checks pass. Its printed sensor coverage (62 %) is below the 70 % guideline, so the app answers "نحتاج بيانات إضافية" instead of triggering rules.
* *Where's the AI?* Optional and server-side; values from it are validated and reconciled, explanations are checked for dosing/diagnostic language and ungrounded numbers, with a local template fallback.
