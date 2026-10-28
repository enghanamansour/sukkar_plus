import '../cgm/metrics_calculator.dart';
import '../cgm/targets.dart';
import '../common/units.dart';
import '../models/cgm.dart';
import '../models/enums.dart';

enum RuleApproval { demonstrationOnly, clinicallyApproved }

enum RuleKind {
  /// A verified summary metric compared with the general reference target of
  /// the user's selected target profile.
  targetExceedance,

  /// Count of low-glucose episodes in raw readings.
  episodeCount,
}

enum RuleStatus { triggered, notTriggered, notAssessable, notApplicable }

/// The four user-facing outcomes. Nothing else is ever shown.
enum ReviewOutcome { routineSummary, reviewSuggested, needMoreData, seekMedicalHelp }

extension ReviewOutcomeInfo on ReviewOutcome {
  String get titleAr => switch (this) {
        ReviewOutcome.routineSummary => 'ملخص روتيني',
        ReviewOutcome.reviewSuggested => 'يُقترح طلب مراجعة بشرية',
        ReviewOutcome.needMoreData => 'نحتاج بيانات إضافية',
        ReviewOutcome.seekMedicalHelp => 'يرجى طلب المساعدة الطبية المناسبة',
      };

  String get explanationAr => switch (this) {
        ReviewOutcome.routineSummary =>
          'عولجت البيانات المتاحة ولم تطلب أي قاعدة مُعدّة مراجعة إضافية. هذا لا يعني أن حالتك آمنة طبيًا، ولا يغني عن متابعتك المعتادة.',
        ReviewOutcome.reviewSuggested =>
          'انطبقت قاعدة مُعدّة على بيانات موثّقة، لذا يمكنك طلب مراجعة بشرية. هذا ليس تشخيصًا ولا تقييمًا لحالة طارئة.',
        ReviewOutcome.needMoreData =>
          'البيانات الحالية ناقصة أو غير كافية لتقييم موثوق. راجع أسباب النقص أدناه.',
        ReviewOutcome.seekMedicalHelp =>
          'إذا كنت تشعر بقلق عاجل على صحتك، تواصل فورًا مع مقدم الرعاية أو خدمات الطوارئ (911 الرقم الموحد، أو 997 الهلال الأحمر في المملكة العربية السعودية). لا يستطيع هذا النموذج الأولي تحديد ما إذا كانت حالتك طارئة.',
      };

  String get wireName => switch (this) {
        ReviewOutcome.routineSummary => 'routine_summary',
        ReviewOutcome.reviewSuggested => 'review_suggested',
        ReviewOutcome.needMoreData => 'need_more_data',
        ReviewOutcome.seekMedicalHelp => 'seek_medical_help',
      };
}

class RuleDefinition {
  const RuleDefinition({
    required this.id,
    required this.version,
    required this.titleAr,
    required this.kind,
    required this.metricDescriptionAr,
    required this.observationWindowAr,
    required this.thresholdDescriptionAr,
    required this.duplicatesPolicyAr,
    required this.gapsPolicyAr,
    required this.sourceRef,
    required this.rationaleAr,
    required this.approval,
    required this.expectedActionAr,
    required this.limitationsAr,
    this.metric,
    this.episodeThresholdMgdl,
    this.minEpisodeMinutes = 15,
    this.minOccurrences = 1,
    this.windowDays,
    this.minDays = DataQuality.minDays,
    this.minCoveragePercent = DataQuality.minCoveragePercent,
    this.enabled = true,
  });

  final String id;
  final int version;
  final String titleAr;
  final RuleKind kind;
  final String metricDescriptionAr;
  final String observationWindowAr;
  final String thresholdDescriptionAr;
  final String duplicatesPolicyAr;
  final String gapsPolicyAr;
  final String sourceRef;
  final String rationaleAr;
  final RuleApproval approval;
  final String expectedActionAr;
  final String limitationsAr;
  final MetricKey? metric;
  final double? episodeThresholdMgdl;
  final int minEpisodeMinutes;
  final int minOccurrences;
  final int? windowDays;
  final int minDays;
  final double minCoveragePercent;
  final bool enabled;

  String get approvalLabelAr => approval == RuleApproval.demonstrationOnly
      ? 'قاعدة عرض تجريبي — تتطلب مراجعة سريرية قبل أي استخدام فعلي'
      : 'قاعدة معتمدة سريريًا';
}

class RuleSet {
  const RuleSet({required this.version, required this.rules});
  final String version;
  final List<RuleDefinition> rules;
}

class RuleResult {
  const RuleResult({required this.rule, required this.status, required this.explanationAr, this.evidence = const {}});
  final RuleDefinition rule;
  final RuleStatus status;
  final String explanationAr;

  /// Verified values that the decision was based on (label → formatted value).
  final Map<String, String> evidence;
}

class RuleEvaluation {
  const RuleEvaluation({
    required this.rulesVersion,
    required this.results,
    required this.outcome,
    required this.reasonsAr,
    required this.limitationsAr,
    required this.evaluatedAt,
  });

  final String rulesVersion;
  final List<RuleResult> results;
  final ReviewOutcome outcome;
  final List<String> reasonsAr;
  final List<String> limitationsAr;
  final DateTime evaluatedAt;

  List<RuleResult> get triggered => results.where((r) => r.status == RuleStatus.triggered).toList();
}

const _dupPolicy = 'تُحذف القراءات المكررة بنفس التوقيت؛ وعند اختلاف القيم يُحتفظ بالأولى وتُسجَّل كملاحظة جودة.';
const _gapPolicyMetric = 'يعتمد على النسبة المطبوعة أو المحسوبة؛ لا تُملأ الفجوات بقيم تقديرية.';
const _gapPolicyEpisodes = 'لا تُدمج النوبات عبر فجوة بيانات أطول من ضعف فاصل القراءات (10 دقائق).';
const _consensus = 'Battelino et al., Diabetes Care 2019;42:1593–1603 (Tables 2–3)';
const _demoLimit =
    'استخدام تجاوز الهدف المرجعي العام كمحفّز لطلب مراجعة هو اختيار تصميمي للعرض، وليس معيار فرز سريري معتمدًا. لا يقيّم الحالات الطارئة.';

/// Default rule set. Every rule is a demonstration rule: thresholds reuse the
/// published general reference targets where possible, but using them to
/// trigger a review task has not been clinically validated.
const defaultRuleSet = RuleSet(version: '2026.10-demo.1', rules: [
  RuleDefinition(
    id: 'TBR54-TARGET',
    version: 1,
    titleAr: 'الوقت أقل من 54 ملغم/دل أعلى من الهدف المرجعي العام',
    kind: RuleKind.targetExceedance,
    metric: MetricKey.timeVeryLow,
    metricDescriptionAr: 'نسبة الوقت أقل من 54 mg/dL (موثّقة).',
    observationWindowAr: 'فترة المؤشرات في التقرير.',
    thresholdDescriptionAr: 'لا يستوفي الهدف المرجعي للفئة المختارة (للبالغين: أقل من 1%).',
    duplicatesPolicyAr: _dupPolicy,
    gapsPolicyAr: _gapPolicyMetric,
    sourceRef: _consensus,
    rationaleAr: 'هدف مرجعي منشور في الإجماع الدولي حول الوقت ضمن النطاق.',
    approval: RuleApproval.demonstrationOnly,
    expectedActionAr: 'اقتراح طلب مراجعة بشرية تجريبية فقط.',
    limitationsAr: _demoLimit,
  ),
  RuleDefinition(
    id: 'TBR70-TARGET',
    version: 1,
    titleAr: 'إجمالي الوقت أقل من 70 ملغم/دل أعلى من الهدف المرجعي العام',
    kind: RuleKind.targetExceedance,
    metric: MetricKey.timeBelowRangeTotal,
    metricDescriptionAr: 'نسبة الوقت أقل من 70 mg/dL (المستويان 1 و2، موثّقة أو محسوبة من فئتين موثّقتين).',
    observationWindowAr: 'فترة المؤشرات في التقرير.',
    thresholdDescriptionAr: 'لا يستوفي الهدف المرجعي للفئة المختارة (للبالغين: أقل من 4%؛ لكبار السن/الأعلى خطورة: أقل من 1%).',
    duplicatesPolicyAr: _dupPolicy,
    gapsPolicyAr: _gapPolicyMetric,
    sourceRef: _consensus,
    rationaleAr: 'هدف مرجعي منشور في الإجماع الدولي حول الوقت ضمن النطاق.',
    approval: RuleApproval.demonstrationOnly,
    expectedActionAr: 'اقتراح طلب مراجعة بشرية تجريبية فقط.',
    limitationsAr: _demoLimit,
  ),
  RuleDefinition(
    id: 'TAR250-TARGET',
    version: 1,
    titleAr: 'الوقت أعلى من 250 ملغم/دل أعلى من الهدف المرجعي العام',
    kind: RuleKind.targetExceedance,
    metric: MetricKey.timeVeryHigh,
    metricDescriptionAr: 'نسبة الوقت أعلى من 250 mg/dL (موثّقة).',
    observationWindowAr: 'فترة المؤشرات في التقرير.',
    thresholdDescriptionAr: 'لا يستوفي الهدف المرجعي للفئة المختارة (للبالغين: أقل من 5%؛ لكبار السن/الأعلى خطورة: أقل من 10%).',
    duplicatesPolicyAr: _dupPolicy,
    gapsPolicyAr: _gapPolicyMetric,
    sourceRef: _consensus,
    rationaleAr: 'هدف مرجعي منشور في الإجماع الدولي حول الوقت ضمن النطاق.',
    approval: RuleApproval.demonstrationOnly,
    expectedActionAr: 'اقتراح طلب مراجعة بشرية تجريبية فقط.',
    limitationsAr: _demoLimit,
  ),
  RuleDefinition(
    id: 'EPI54-REPEATED',
    version: 1,
    titleAr: 'نوبات متكررة أقل من 54 ملغم/دل في القراءات التفصيلية',
    kind: RuleKind.episodeCount,
    episodeThresholdMgdl: 54,
    minEpisodeMinutes: 15,
    minOccurrences: 2,
    windowDays: 14,
    metricDescriptionAr: 'عدد النوبات التي بقيت فيها القراءات أقل من 54 mg/dL مدة 15 دقيقة متصلة على الأقل.',
    observationWindowAr: 'آخر 14 يومًا من القراءات التفصيلية.',
    thresholdDescriptionAr: 'نوبتان أو أكثر (عدد تجريبي قابل للتعديل، غير مستمد من مصدر).',
    duplicatesPolicyAr: _dupPolicy,
    gapsPolicyAr: _gapPolicyEpisodes,
    sourceRef:
        'تعريف مدة النوبة (15 دقيقة) من الإجماع الدولي 2017 المشار إليه في الجدول 1 من ورقة 2019؛ عدد النوبات (2) قيمة تجريبية.',
    rationaleAr: 'تكرار انخفاض السكر عن 54 أمر يستحق النقاش، لكن العدد المختار هنا للعرض فقط.',
    approval: RuleApproval.demonstrationOnly,
    expectedActionAr: 'اقتراح طلب مراجعة بشرية تجريبية فقط.',
    limitationsAr: 'تتطلب قراءات تفصيلية بتوقيتات؛ لا تنطبق على ملفات PDF التي تحتوي ملخصات فقط. لا تقيّم الحالات الطارئة.',
  ),
]);

/// Evaluates the configured rules against an accepted report.
class RuleEngine {
  const RuleEngine({this.ruleSet = defaultRuleSet, this.calculator = const CgmCalculator()});
  final RuleSet ruleSet;
  final CgmCalculator calculator;

  RuleEvaluation evaluate(CgmReport report, {required TargetProfile profile, required DateTime now}) {
    final targets = consensusTargetsFor(profile);
    final results = <RuleResult>[];
    final limitations = <String>[];

    for (final rule in ruleSet.rules.where((r) => r.enabled)) {
      switch (rule.kind) {
        case RuleKind.targetExceedance:
          results.add(_evalTarget(rule, report, targets));
        case RuleKind.episodeCount:
          results.add(_evalEpisodes(rule, report));
      }
    }

    for (final r in results) {
      if (r.status == RuleStatus.notApplicable) limitations.add(r.explanationAr);
    }
    final triggered = results.where((r) => r.status == RuleStatus.triggered).toList();
    final notAssessable = results.where((r) => r.status == RuleStatus.notAssessable).toList();

    final ReviewOutcome outcome;
    final reasons = <String>[];
    if (triggered.isNotEmpty) {
      outcome = ReviewOutcome.reviewSuggested;
      reasons.addAll(triggered.map((r) => r.explanationAr));
      if (notAssessable.isNotEmpty) {
        reasons.add('تعذّر تقييم بعض القواعد الأخرى بسبب نقص البيانات.');
      }
    } else if (notAssessable.isNotEmpty || !report.quality.sufficient) {
      outcome = ReviewOutcome.needMoreData;
      reasons.addAll(report.quality.reasonsAr);
      reasons.addAll(notAssessable.map((r) => r.explanationAr).toSet());
    } else {
      outcome = ReviewOutcome.routineSummary;
    }
    return RuleEvaluation(
      rulesVersion: ruleSet.version,
      results: results,
      outcome: outcome,
      reasonsAr: reasons.toSet().toList(),
      limitationsAr: limitations,
      evaluatedAt: now,
    );
  }

  /// Only ever called when the user explicitly reports an urgent concern.
  /// The response is general safety messaging; no assessment is attempted.
  ReviewOutcome urgentConcernOutcome() => ReviewOutcome.seekMedicalHelp;

  String? _qualityGate(RuleDefinition rule, CgmReport report) {
    final q = report.quality;
    if (q.daysOfData == null || q.daysOfData! < rule.minDays) {
      return 'مدة البيانات أقل من ${rule.minDays} يومًا أو غير معروفة.';
    }
    if (q.coveragePercent == null || q.coveragePercent! < rule.minCoveragePercent) {
      return 'تغطية بيانات الحساس أقل من ${formatNumber(rule.minCoveragePercent)}% أو غير مؤكدة.';
    }
    return null;
  }

  RuleResult _evalTarget(RuleDefinition rule, CgmReport report, TargetSet targets) {
    final key = rule.metric!;
    if (targets.isEmpty) {
      return RuleResult(
        rule: rule,
        status: RuleStatus.notAssessable,
        explanationAr: 'لا توجد أهداف مرجعية مطبّقة للفئة المختارة (${targets.profile.labelAr})؛ نحتاج أهدافًا من الفريق الصحي.',
      );
    }
    final spec = targets[key];
    if (spec == null) {
      return RuleResult(
        rule: rule,
        status: RuleStatus.notApplicable,
        explanationAr: 'لا يحدد الإجماع هدفًا عامًا منفصلًا لـ "${key.labelAr}" لهذه الفئة.',
      );
    }
    final gate = _qualityGate(rule, report);
    if (gate != null) {
      return RuleResult(rule: rule, status: RuleStatus.notAssessable, explanationAr: '${rule.titleAr}: $gate');
    }
    final v = report.verifiedValue(key);
    if (v == null) {
      return RuleResult(rule: rule, status: RuleStatus.notAssessable, explanationAr: '"${key.labelAr}" غير متاح أو غير موثّق.');
    }
    final evidence = {key.labelAr: '${formatNumber(v)}%', 'الهدف المرجعي العام': spec.textAr};
    if (spec.isMetBy(v)) {
      return RuleResult(
        rule: rule,
        status: RuleStatus.notTriggered,
        explanationAr: '${key.labelAr} ${formatNumber(v)}% ضمن الهدف المرجعي العام (${spec.textAr}).',
        evidence: evidence,
      );
    }
    return RuleResult(
      rule: rule,
      status: RuleStatus.triggered,
      explanationAr: '${key.labelAr} ${formatNumber(v)}% لا يستوفي الهدف المرجعي العام (${spec.textAr}) — قاعدة ${rule.id} v${rule.version}.',
      evidence: evidence,
    );
  }

  RuleResult _evalEpisodes(RuleDefinition rule, CgmReport report) {
    if (!report.hasRawReadings) {
      return RuleResult(
        rule: rule,
        status: RuleStatus.notApplicable,
        explanationAr: 'لا يمكن تقييم النوبات المتكررة لعدم توفر قراءات تفصيلية بتوقيتاتها في هذا التقرير.',
      );
    }
    final gate = _qualityGate(rule, report);
    if (gate != null) {
      return RuleResult(rule: rule, status: RuleStatus.notAssessable, explanationAr: '${rule.titleAr}: $gate');
    }
    final period = report.effectivePeriod;
    ReportPeriod? window;
    if (period != null && rule.windowDays != null) {
      final start = period.end.subtract(Duration(days: rule.windowDays! - 1));
      window = ReportPeriod(start.isBefore(period.start) ? period.start : start, period.end);
    }
    final comp = calculator.compute(report.readings!, window: window);
    final episodes = calculator.detectEpisodesBelow(comp.cleanedReadings, rule.episodeThresholdMgdl!)
        .where((e) => e.durationMinutes >= rule.minEpisodeMinutes)
        .toList();
    final evidence = {
      'عدد النوبات أقل من ${formatNumber(rule.episodeThresholdMgdl!)}': '${episodes.length}',
      'فترة التقييم': window?.toString() ?? '',
    };
    if (episodes.length >= rule.minOccurrences) {
      return RuleResult(
        rule: rule,
        status: RuleStatus.triggered,
        explanationAr:
            'رُصدت ${episodes.length} نوبات انخفاض أقل من 54 mg/dL لمدة 15 دقيقة أو أكثر خلال آخر ${rule.windowDays} يومًا (الحد التجريبي ${rule.minOccurrences}) — قاعدة ${rule.id} v${rule.version}.',
        evidence: evidence,
      );
    }
    return RuleResult(
      rule: rule,
      status: RuleStatus.notTriggered,
      explanationAr: 'رُصدت ${episodes.length} نوبة انخفاض أقل من 54 mg/dL، وهو أقل من الحد التجريبي (${rule.minOccurrences}).',
      evidence: evidence,
    );
  }
}
