import '../cgm/metrics_calculator.dart';
import '../common/units.dart';
import '../extraction/review.dart';
import '../followup/followup_workflow.dart';
import '../models/care.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import '../models/followup.dart';
import '../models/lab.dart';
import '../repository/health_repository.dart';
import '../rules/rules.dart';
import 'synthetic.dart';

const demoPatientId = 'demo-patient-1';
const demoReviewerId = 'demo-reviewer-1';
const demoPatientActor = Actor(userId: demoPatientId, role: UserRole.patient);
const demoReviewerActor = Actor(userId: demoReviewerId, role: UserRole.reviewer);

/// Text pages for the in-app demo "upload" (rendered to a real PDF by the app).
/// Period: the 14 days ending yesterday.
List<String> demoUploadLines(DateTime now) {
  final end = dateOnly(now).subtract(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 13));
  return syntheticDiscoverSummaryLines(periodStart: start, periodEnd: end, generated: dateOnly(now), v: demoUploadValues);
}

/// Builds a fully SYNTHETIC demo dataset relative to [now]. Every record is
/// marked [DataProvenance.synthetic]. Nothing here comes from the supplied
/// real report or from the AZT1D dataset.
InMemoryHealthRepository buildDemoRepository(DateTime now) {
  final repo = InMemoryHealthRepository(isDemo: true);
  final today = dateOnly(now);
  DateTime ago(int d) => today.subtract(Duration(days: d));
  DateTime ahead(int d) => today.add(Duration(days: d));

  repo.profiles[demoPatientId] = const PatientProfile(
    userId: demoPatientId,
    pseudoId: 'SP-4821',
    displayName: 'سارة (اسم تجريبي)',
    role: UserRole.patient,
    targetProfile: TargetProfile.generalAdultT1T2,
    provenance: DataProvenance.synthetic,
  );
  repo.profiles[demoReviewerId] = const PatientProfile(
    userId: demoReviewerId,
    pseudoId: 'RV-0001',
    displayName: 'مراجع تجريبي',
    role: UserRole.reviewer,
    targetProfile: TargetProfile.unspecified,
    provenance: DataProvenance.synthetic,
  );

  // Report A: printed-summary report (synthetic text, parsed like an upload).
  final aLines = syntheticDiscoverSummaryLines(periodStart: ago(104), periodEnd: ago(91), generated: ago(90), v: demoReportAValues);
  var extraction = reportTextParser.parse([aLines.join('\n')]);
  extraction = ExtractionReview.confirmAllEligible(extraction);
  final reportA = buildReportFromExtraction(
    extraction,
    id: 'demo-report-a',
    userId: demoPatientId,
    provenance: DataProvenance.synthetic,
    sourceType: ReportSourceType.demoFixture,
    createdAt: ago(90),
  );

  // Report B: synthetic raw readings, metrics calculated deterministically.
  final bStart = ago(60);
  final readings = syntheticReadings(startDay: bStart);
  final period = ReportPeriod(bStart, bStart.add(const Duration(days: 13)));
  final comp = const CgmCalculator().compute(readings, window: period);
  final reportB = CgmReport(
    id: 'demo-report-b',
    userId: demoPatientId,
    provenance: DataProvenance.synthetic,
    sourceType: ReportSourceType.demoFixture,
    glucoseUnit: GlucoseUnit.mgdl,
    metrics: comp.metrics,
    quality: comp.quality,
    createdAt: ago(46),
    reportPeriod: period,
    metricsPeriod: period,
    formatId: 'synthetic_readings_v1',
    deviceLabel: 'قراءات حساس تجريبية',
    readings: comp.cleanedReadings,
    warningsAr: const ['قراءات تجريبية مولّدة آليًا، ليست لشخص حقيقي.'],
  );
  repo.reports[reportA.id] = reportA;
  repo.reports[reportB.id] = reportB;

  LabResult lab(String id, LabTestCode code, double value, String unit, DateTime date, {ReferenceInterval? ri, String? name}) => LabResult(
        id: id,
        userId: demoPatientId,
        testCode: code,
        testName: name ?? code.labelAr,
        value: value,
        unit: unit,
        collectionDate: date,
        source: LabSource.manual,
        verification: VerificationStatus.verified,
        provenance: DataProvenance.synthetic,
        createdAt: date,
        referenceInterval: ri,
        labName: 'مختبر تجريبي',
      );

  for (final l in [
    lab('demo-lab-hba1c-1', LabTestCode.hba1c, 7.6, '%', ago(88), ri: const ReferenceInterval(text: 'كما يطبعه المختبر')),
    lab('demo-lab-hba1c-2', LabTestCode.hba1c, 54, 'mmol/mol', ago(45)),
    lab('demo-lab-egfr-1', LabTestCode.egfr, 98, 'mL/min/1.73m²', ago(45), ri: const ReferenceInterval(low: 90, text: '≥ 90 (مرجع المختبر)')),
    lab('demo-lab-ldl-1', LabTestCode.ldl, 104, 'mg/dL', ago(45), ri: const ReferenceInterval(high: 100, text: '< 100 (مرجع المختبر)')),
  ]) {
    repo.labs[l.id] = l;
  }

  const appt = 'demo-appt-1';
  repo.appointments[appt] = Appointment(
    id: appt,
    userId: demoPatientId,
    dateTime: DateTime(today.year, today.month, today.day + 12, 10, 30),
    clinicLabel: 'عيادة السكري — موعد محاكى (ليس حجزًا حقيقيًا)',
    provenance: DataProvenance.synthetic,
  );

  TestReminder reminder(String id, LabTestCode code, DateTime due, ReminderStatus status, {DateTime? done}) => TestReminder(
        id: id,
        userId: demoPatientId,
        testCode: code,
        testName: code.labelAr,
        dueDate: due,
        source: ScheduleSource.clinicianProvided,
        status: status,
        provenance: DataProvenance.synthetic,
        remindAt: DateTime(due.year, due.month, due.day - 1, 9),
        appointmentId: status == ReminderStatus.scheduled ? appt : null,
        completedAt: done,
        collectionDate: done,
        note: 'جدول تجريبي يمثل طلبًا من مقدم الرعاية',
        history: [ReminderEvent(ago(60), 'أُنشئ التذكير (بطلب من مقدم الرعاية — بيانات تجريبية)')],
      );
  for (final r in [
    reminder('demo-rem-hba1c', LabTestCode.hba1c, ahead(6), ReminderStatus.scheduled),
    reminder('demo-rem-uacr', LabTestCode.uacr, ahead(9), ReminderStatus.scheduled),
    reminder('demo-rem-egfr', LabTestCode.egfr, ago(46), ReminderStatus.completed, done: ago(45)),
  ]) {
    repo.reminders[r.id] = r;
  }

  // Follow-up requests: one pending (rule-based, report B) and one reviewed.
  const wf = FollowUpWorkflow();
  final evalB = const RuleEngine().evaluate(reportB, profile: TargetProfile.generalAdultT1T2, now: ago(2));
  final ruleIds = evalB.triggered.map((r) => r.rule.id).toList();
  var pending = wf.createDraft(
    id: 'demo-fu-pending',
    pseudoId: 'REQ-7Q2K',
    userId: demoPatientId,
    trigger: ruleIds.isEmpty ? FollowUpTrigger.userRequest : FollowUpTrigger.rule,
    ruleIds: ruleIds,
    rulesVersion: defaultRuleSet.version,
    reasonAr: ruleIds.isEmpty ? 'طلب المستخدم مراجعة بيانات الحساس.' : evalB.triggered.map((r) => r.explanationAr).join('\n'),
    snapshot: snapshotFromReport(reportB),
    now: ago(2),
    existing: const [],
    provenance: DataProvenance.synthetic,
    reportId: reportB.id,
  );
  pending = wf.submit(pending, demoPatientActor, ago(2));
  pending = pending.copyWith(dispatch: IntegrationDispatch(state: DispatchState.mockRecorded, adapterName: 'local-mock', isMock: true, attempts: 1, lastAttemptAt: ago(2)));

  var done = wf.createDraft(
    id: 'demo-fu-done',
    pseudoId: 'REQ-3M8D',
    userId: demoPatientId,
    trigger: FollowUpTrigger.userRequest,
    ruleIds: const [],
    rulesVersion: defaultRuleSet.version,
    reasonAr: 'طلب المستخدم مراجعة تقرير الحساس قبل الموعد.',
    snapshot: snapshotFromReport(reportA),
    now: ago(89),
    existing: const [],
    provenance: DataProvenance.synthetic,
    reportId: reportA.id,
  );
  done = wf.submit(done, demoPatientActor, ago(89));
  done = wf.startReview(done, demoReviewerActor, ago(88));
  done = wf.decide(done, demoReviewerActor, ago(88), ReviewDecision.reviewRequired,
      noteAr: 'ملاحظة تجريبية: يُقترح عرض التقرير على الفريق الصحي في الموعد القادم. لا يتضمن ذلك تشخيصًا.');
  done = done.copyWith(dispatch: IntegrationDispatch(state: DispatchState.mockRecorded, adapterName: 'local-mock', isMock: true, attempts: 1, lastAttemptAt: ago(89)));

  repo.followUps[pending.id] = pending;
  repo.followUps[done.id] = done;
  return repo;
}

/// The information a patient agrees to share with a reviewer: verified
/// metrics of one report plus its period and data-quality notes.
SharedSnapshot snapshotFromReport(CgmReport r) {
  final items = <String, String>{};
  const order = [
    MetricKey.timeInRange,
    MetricKey.timeBelowRangeTotal,
    MetricKey.timeVeryLow,
    MetricKey.timeAboveRangeTotal,
    MetricKey.timeVeryHigh,
    MetricKey.meanGlucose,
    MetricKey.gmi,
    MetricKey.cv,
    MetricKey.sensorActive,
  ];
  for (final k in order) {
    final m = r.metrics[k];
    if (m == null || !m.isVerified) continue;
    items[k.labelAr] = '${formatNumber(m.value!)}${m.unit == '%' ? '%' : ' ${m.unit}'} (${m.origin.labelAr})';
  }
  final p = r.effectivePeriod;
  return SharedSnapshot(
    periodLabel: p == null ? 'غير معروفة' : '${arPeriod(p.start, p.end)} (${p.days} يومًا)',
    items: items,
    qualityNotesAr: r.quality.reasonsAr,
  );
}
