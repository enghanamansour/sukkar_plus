import '../common/units.dart';
import '../labs/hba1c.dart';
import '../models/cgm.dart';
import '../models/lab.dart';

enum Comparability {
  /// Both values verified, lab dated, and lab date within the alignment window.
  aligned,

  /// Both values exist but the dates/windows do not line up; values are shown
  /// side by side without a difference.
  notAligned,

  /// One of the values is missing, undated or unverified.
  insufficient,
}

extension ComparabilityAr on Comparability {
  String get labelAr => switch (this) {
        Comparability.aligned => 'فترتان متقاربتان زمنيًا',
        Comparability.notAligned => 'الفترتان غير متقاربتين',
        Comparability.insufficient => 'بيانات غير كافية للمقارنة',
      };
}

/// Display methodology (not a clinical rule, see LAB_COMPARISON_METHODOLOGY.md):
/// the lab sample must be collected during the CGM metrics period or within
/// [maxDaysAfterPeriodEnd] days after it. Configurable.
class GmiHbA1cConfig {
  const GmiHbA1cConfig({this.maxDaysAfterPeriodEnd = 30});
  final int maxDaysAfterPeriodEnd;
}

class GmiHbA1cComparison {
  const GmiHbA1cComparison({
    required this.comparability,
    required this.notesAr,
    this.hba1c,
    this.hba1cPercent,
    this.hba1cWasConverted = false,
    this.gmiPercent,
    this.gmiOrigin,
    this.period,
    this.daysFromPeriodEndToLab,
    this.differencePercentPoints,
    this.reportId,
  });

  final Comparability comparability;
  final List<String> notesAr;
  final LabResult? hba1c;

  /// HbA1c expressed in % (converted from mmol/mol when needed).
  final double? hba1cPercent;
  final bool hba1cWasConverted;
  final double? gmiPercent;
  final String? gmiOrigin;
  final ReportPeriod? period;

  /// Positive = lab collected after the CGM period ended.
  final int? daysFromPeriodEndToLab;

  /// HbA1c (%) − GMI (%), only when [comparability] is aligned.
  final double? differencePercentPoints;
  final String? reportId;

  static const explanationGmiAr =
      'مؤشر إدارة الجلوكوز (GMI) تقدير محسوب من متوسط قراءات الحساس خلال فترة التقرير فقط، وليس تحليلًا مخبريًا.';
  static const explanationHbA1cAr =
      'السكر التراكمي (HbA1c) تحليل دم مخبري يعكس متوسط السكر خلال الأسابيع إلى الأشهر السابقة لسحب العينة.';
  static const neutralityNoteAr =
      'القيمتان ليستا متطابقتين بطبيعتهما، وقد تختلفان لأسباب عديدة. الاختلاف وحده لا يعني تشخيصًا أو سببًا محددًا؛ ناقشه مع فريقك الصحي.';
}

/// Compares the GMI of a CGM report with an HbA1c laboratory result.
GmiHbA1cComparison compareGmiWithHbA1c({
  required CgmReport? report,
  required LabResult? hba1c,
  GmiHbA1cConfig config = const GmiHbA1cConfig(),
}) {
  final notes = <String>[];
  final gmiMetric = report?.metrics[MetricKey.gmi];
  final gmi = (gmiMetric != null && gmiMetric.isVerified) ? gmiMetric.value : null;
  final gmiOrigin = gmiMetric?.origin.name;
  final period = report?.effectivePeriod;

  double? labPct;
  var converted = false;
  if (hba1c != null) {
    final unit = parseHbA1cUnit(hba1c.unit);
    if (unit != null) {
      labPct = HbA1c.toPercent(hba1c.value, unit);
      converted = unit == HbA1cUnit.mmolMol;
      if (converted) notes.add('حُوّلت نتيجة HbA1c من mmol/mol إلى % بمعادلة التحويل المعيارية للمقارنة فقط.');
    } else {
      notes.add('وحدة نتيجة HbA1c غير معروفة، لذا لا يمكن المقارنة.');
    }
  }

  GmiHbA1cComparison insufficient(String why) => GmiHbA1cComparison(
        comparability: Comparability.insufficient,
        notesAr: [why, ...notes],
        hba1c: hba1c,
        hba1cPercent: labPct,
        hba1cWasConverted: converted,
        gmiPercent: gmi,
        gmiOrigin: gmiOrigin,
        period: period,
        reportId: report?.id,
      );

  if (report == null) return insufficient('لا يوجد تقرير حساس موثّق.');
  if (gmi == null) return insufficient('قيمة GMI غير متاحة أو غير موثّقة في التقرير.');
  if (hba1c == null) return insufficient('لا توجد نتيجة HbA1c مسجلة.');
  if (!hba1c.isVerified) return insufficient('نتيجة HbA1c لم تُؤكَّد بعد.');
  if (hba1c.collectionDate == null) return insufficient('نتيجة HbA1c بلا تاريخ سحب، فلا يمكن ربطها بفترة الحساس.');
  if (labPct == null) return insufficient('تعذّر قراءة وحدة HbA1c.');
  if (period == null) return insufficient('فترة بيانات الحساس غير معروفة.');

  final lag = daysBetween(period.end, hba1c.collectionDate!);
  final withinPeriod = period.contains(hba1c.collectionDate!);
  final aligned = withinPeriod || (lag >= 0 && lag <= config.maxDaysAfterPeriodEnd);

  if (!report.quality.sufficient) {
    notes.add('بيانات الحساس في هذه الفترة لا تستوفي الحد العام (14 يومًا و70% تغطية)، لذا قد لا يمثل GMI الفترة بدقة.');
  }
  if (!aligned) {
    notes.add(lag < 0
        ? 'سُحبت عينة HbA1c قبل نهاية فترة الحساس بـ ${-lag} يومًا وخارجها، لذا لا تُحسب الفروق.'
        : 'سُحبت عينة HbA1c بعد نهاية فترة الحساس بـ $lag يومًا (أكثر من ${config.maxDaysAfterPeriodEnd} يومًا)، لذا لا تُحسب الفروق.');
  }
  return GmiHbA1cComparison(
    comparability: aligned ? Comparability.aligned : Comparability.notAligned,
    notesAr: notes,
    hba1c: hba1c,
    hba1cPercent: labPct,
    hba1cWasConverted: converted,
    gmiPercent: gmi,
    gmiOrigin: gmiOrigin,
    period: period,
    daysFromPeriodEndToLab: lag,
    differencePercentPoints: aligned ? labPct - gmi : null,
    reportId: report.id,
  );
}

/// Picks the report/lab pair to show by default: the latest verified HbA1c
/// and the report whose period end is closest before (or containing) it.
GmiHbA1cComparison compareLatest({
  required List<CgmReport> reports,
  required List<LabResult> labs,
  GmiHbA1cConfig config = const GmiHbA1cConfig(),
}) {
  final hba = comparableHbA1c(labs);
  final latestLab = hba.isEmpty ? null : hba.last;
  final withGmi = reports.where((r) => (r.metrics[MetricKey.gmi]?.isVerified ?? false) && r.effectivePeriod != null).toList()
    ..sort((a, b) => a.effectivePeriod!.end.compareTo(b.effectivePeriod!.end));
  if (withGmi.isEmpty || latestLab == null) {
    // Still return context for the UI (e.g. undated or unverified lab).
    final anyHbA1c = labs.where((l) => l.testCode == LabTestCode.hba1c).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return compareGmiWithHbA1c(
      report: withGmi.isEmpty ? (reports.isEmpty ? null : reports.last) : withGmi.last,
      hba1c: latestLab ?? (anyHbA1c.isEmpty ? null : anyHbA1c.first),
      config: config,
    );
  }
  CgmReport best = withGmi.last;
  for (final r in withGmi.reversed) {
    if (!r.effectivePeriod!.start.isAfter(latestLab.collectionDate!)) {
      best = r;
      break;
    }
  }
  return compareGmiWithHbA1c(report: best, hba1c: latestLab, config: config);
}
