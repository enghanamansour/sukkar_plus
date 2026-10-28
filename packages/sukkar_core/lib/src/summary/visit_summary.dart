import '../cgm/targets.dart';
import '../common/units.dart';
import '../comparison/gmi_hba1c.dart';
import '../comparison/trends.dart';
import '../labs/hba1c.dart';
import '../models/care.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import '../models/followup.dart';
import '../models/lab.dart';
import '../reminders/reminder_service.dart';
import '../rules/rules.dart';

class SummaryLine {
  const SummaryLine(this.labelAr, this.valueAr, {this.noteAr});
  final String labelAr;
  final String valueAr;
  final String? noteAr;
}

class VisitSummary {
  const VisitSummary({
    required this.generatedAt,
    required this.isSynthetic,
    required this.appointment,
    required this.latestReport,
    required this.latestMetrics,
    required this.qualityWarningsAr,
    required this.cgmComparison,
    required this.labLines,
    required this.hba1cTrend,
    required this.gmiComparison,
    required this.reminderLines,
    required this.dueBeforeAppointment,
    required this.followUpLines,
    required this.missingAr,
    required this.questionsAr,
    required this.ruleOutcome,
    required this.targetNotesAr,
  });

  final DateTime generatedAt;
  final bool isSynthetic;
  final Appointment? appointment;
  final CgmReport? latestReport;
  final List<SummaryLine> latestMetrics;
  final List<String> qualityWarningsAr;
  final CgmPeriodComparison? cgmComparison;
  final List<SummaryLine> labLines;
  final TrendSeries hba1cTrend;
  final GmiHbA1cComparison gmiComparison;
  final List<SummaryLine> reminderLines;
  final List<TestReminder> dueBeforeAppointment;
  final List<SummaryLine> followUpLines;
  final List<String> missingAr;
  final List<String> questionsAr;
  final RuleEvaluation? ruleOutcome;
  final List<String> targetNotesAr;

  static const disclaimerAr =
      'هذا الملخص تعليمي لمساعدتك على الاستعداد لموعدك، أعدّه نموذج أولي مستقل (سكر بلس) غير مرتبط بأي جهة صحية. '
      'لا يتضمن تشخيصًا أو توصيات علاجية أو جرعات، ولا يغني عن تقييم فريقك الصحي.';
}

String _metricValue(MetricValue m) {
  if (m.value == null) return 'غير متاح';
  final u = m.unit == '%' ? '%' : ' ${m.unit}';
  return '${formatNumber(m.value!, decimals: 1)}$u';
}

const summaryMetricOrder = [
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

/// Builds the appointment-preparation summary from verified data only.
class VisitSummaryBuilder {
  const VisitSummaryBuilder({this.ruleEngine = const RuleEngine(), this.reminderService = const ReminderService()});
  final RuleEngine ruleEngine;
  final ReminderService reminderService;

  VisitSummary build({
    required DateTime now,
    required List<CgmReport> reports,
    required List<LabResult> labs,
    required List<TestReminder> reminders,
    required List<FollowUpRequest> followUps,
    required Appointment? appointment,
    required TargetProfile targetProfile,
  }) {
    final sorted = reports.where((r) => r.effectivePeriod != null).toList()
      ..sort((a, b) => a.effectivePeriod!.end.compareTo(b.effectivePeriod!.end));
    final latest = sorted.isEmpty ? (reports.isEmpty ? null : reports.last) : sorted.last;
    final missing = <String>[];

    final metrics = <SummaryLine>[];
    if (latest != null) {
      for (final k in summaryMetricOrder) {
        final m = latest.metrics[k];
        if (m == null || !m.isVerified) {
          metrics.add(SummaryLine(k.labelAr, 'غير متاح'));
          continue;
        }
        metrics.add(SummaryLine(k.labelAr, _metricValue(m), noteAr: m.origin.labelAr));
      }
    } else {
      missing.add('لا يوجد تقرير حساس موثّق.');
    }

    final quality = <String>[if (latest != null) ...latest.quality.reasonsAr];
    final cgmCmp = compareLatestCgmPeriods(reports);
    if (cgmCmp == null) missing.add('لا يوجد تقريران بفترات معروفة للمقارنة التاريخية.');

    final labLines = <SummaryLine>[];
    final byDate = [...labs]..sort((a, b) => (b.collectionDate ?? b.createdAt).compareTo(a.collectionDate ?? a.createdAt));
    for (final l in byDate) {
      final value = l.testCode == LabTestCode.hba1c ? hba1cDisplay(l) : '${formatNumber(l.value, decimals: 2)} ${l.unit}';
      final date = l.collectionDate == null ? 'بلا تاريخ' : arDate(l.collectionDate!);
      final ref = (l.referenceInterval == null || l.referenceInterval!.isEmpty) ? null : 'المرجع المخبري: ${l.referenceInterval!.describe(l.unit)}';
      labLines.add(SummaryLine(l.testName, '$value — $date${l.isVerified ? '' : ' (غير مؤكدة)'}', noteAr: ref));
    }
    if (!labs.any((l) => l.testCode == LabTestCode.hba1c)) missing.add('لا توجد نتيجة HbA1c مسجلة.');

    final trend = hba1cTrend(labs);
    final gmiCmp = compareLatest(reports: reports, labs: labs);

    final due = appointment == null ? <TestReminder>[] : reminderService.dueBeforeAppointment(reminders, appointment);
    final reminderLines = [
      for (final r in reminders)
        SummaryLine(r.testName, '${r.displayState(now).labelAr} — الاستحقاق ${arDate(r.dueDate)}', noteAr: r.source.labelAr),
    ];

    final followLines = [
      for (final f in followUps)
        SummaryLine('طلب ${f.pseudoId}', f.status.labelAr, noteAr: f.decision?.labelAr),
    ];

    RuleEvaluation? evaluation;
    if (latest != null) evaluation = ruleEngine.evaluate(latest, profile: targetProfile, now: now);

    final questions = generateQuestions(
      gmiComparison: gmiCmp,
      latest: latest,
      evaluation: evaluation,
      hba1cTrend: trend,
      dueBeforeAppointment: due,
      hasAppointment: appointment != null,
      followUps: followUps,
      targetProfile: targetProfile,
    );

    return VisitSummary(
      generatedAt: now,
      isSynthetic: reports.any((r) => r.provenance == DataProvenance.synthetic) || labs.any((l) => l.provenance == DataProvenance.synthetic),
      appointment: appointment,
      latestReport: latest,
      latestMetrics: metrics,
      qualityWarningsAr: quality,
      cgmComparison: cgmCmp,
      labLines: labLines,
      hba1cTrend: trend,
      gmiComparison: gmiCmp,
      reminderLines: reminderLines,
      dueBeforeAppointment: due,
      followUpLines: followLines,
      missingAr: [...missing, ...trend.missingAr],
      questionsAr: questions,
      ruleOutcome: evaluation,
      targetNotesAr: consensusTargetsFor(targetProfile).notesAr,
    );
  }
}

/// Neutral questions the user may choose to ask. They depend only on which
/// data exist; they never contain values that are not verified.
List<String> generateQuestions({
  required GmiHbA1cComparison gmiComparison,
  required CgmReport? latest,
  required RuleEvaluation? evaluation,
  required TrendSeries hba1cTrend,
  required List<TestReminder> dueBeforeAppointment,
  required bool hasAppointment,
  required List<FollowUpRequest> followUps,
  required TargetProfile targetProfile,
}) {
  final q = <String>[];
  if (gmiComparison.gmiPercent != null && gmiComparison.hba1cPercent != null) {
    q.add('كيف تفسر اختلاف قيمة GMI عن آخر نتيجة HbA1c؟');
  }
  if (latest != null && !latest.quality.sufficient) {
    q.add('هل فترة بيانات الحساس كافية لتقييم الأنماط؟');
  }
  if (hasAppointment) {
    q.add(dueBeforeAppointment.isEmpty
        ? 'هل توجد تحاليل أو فحوصات دورية مطلوبة قبل الموعد؟'
        : 'هل التحاليل المجدولة قبل الموعد ما زالت مطلوبة، وهل أحتاج غيرها؟');
  }
  if (evaluation != null && evaluation.triggered.isNotEmpty) {
    q.add('ما المعلومات الإضافية التي تساعد في فهم الأنماط المتكررة؟');
  }
  if (hba1cTrend.hasComparison) {
    q.add('كيف أفهم التغيّر بين آخر نتيجتين لـ HbA1c؟');
  }
  if (targetProfile == TargetProfile.unspecified || targetProfile == TargetProfile.pregnancy || targetProfile == TargetProfile.pediatric) {
    q.add('ما الأهداف المناسبة لي لنطاقات السكر؟');
  } else {
    q.add('هل الأهداف المرجعية العامة لنطاقات السكر مناسبة لي أم تحتاج إلى تخصيص؟');
  }
  if (followUps.any((f) => f.status != FollowUpStatus.closed && f.status != FollowUpStatus.draft)) {
    q.add('هل يمكن مناقشة البيانات التي دفعتني إلى طلب مراجعة عبر التطبيق؟');
  }
  return q;
}
