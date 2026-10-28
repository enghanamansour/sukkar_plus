import '../models/cgm.dart';
import '../models/enums.dart';

enum TargetComparator { greaterThan, lessThan, lessOrEqual }

/// A general reference target from the 2019 International Consensus on Time
/// in Range. These are population-level reference targets, not personalised
/// goals, and are only displayed for the profile they belong to.
class TargetSpec {
  const TargetSpec(this.key, this.comparator, this.value, this.sourceRef);
  final MetricKey key;
  final TargetComparator comparator;
  final double value;
  final String sourceRef;

  bool isMetBy(double v) => switch (comparator) {
        TargetComparator.greaterThan => v > value,
        TargetComparator.lessThan => v < value,
        TargetComparator.lessOrEqual => v <= value,
      };

  String get textAr {
    final op = switch (comparator) {
      TargetComparator.greaterThan => 'أكثر من',
      TargetComparator.lessThan => 'أقل من',
      TargetComparator.lessOrEqual => 'لا يزيد على',
    };
    final v = value == value.truncateToDouble() ? value.toInt().toString() : value.toString();
    return '$op $v%';
  }
}

class TargetSet {
  const TargetSet(this.profile, this.targets, this.notesAr);
  final TargetProfile profile;
  final Map<MetricKey, TargetSpec> targets;
  final List<String> notesAr;

  bool get isEmpty => targets.isEmpty;
  TargetSpec? operator [](MetricKey k) => targets[k];
}

const _t3 = 'Battelino et al., Diabetes Care 2019;42:1593–1603, Table 3';
const _t2 = 'Battelino et al., Diabetes Care 2019;42:1593–1603, Table 2';

/// Returns the general reference targets for a profile. Pregnancy, pediatric
/// and unspecified profiles return an empty set: those targets must come from
/// the care team (pregnancy targets use different glucose ranges, Table 4).
TargetSet consensusTargetsFor(TargetProfile profile) {
  switch (profile) {
    case TargetProfile.generalAdultT1T2:
      return const TargetSet(TargetProfile.generalAdultT1T2, {
        MetricKey.timeInRange: TargetSpec(MetricKey.timeInRange, TargetComparator.greaterThan, 70, _t3),
        MetricKey.timeBelowRangeTotal: TargetSpec(MetricKey.timeBelowRangeTotal, TargetComparator.lessThan, 4, _t3),
        MetricKey.timeVeryLow: TargetSpec(MetricKey.timeVeryLow, TargetComparator.lessThan, 1, _t3),
        MetricKey.timeAboveRangeTotal: TargetSpec(MetricKey.timeAboveRangeTotal, TargetComparator.lessThan, 25, _t3),
        MetricKey.timeVeryHigh: TargetSpec(MetricKey.timeVeryHigh, TargetComparator.lessThan, 5, _t3),
        MetricKey.cv: TargetSpec(MetricKey.cv, TargetComparator.lessOrEqual, 36, _t2),
      }, [
        'أهداف مرجعية عامة لكثير من البالغين المصابين بالسكري من النوع الأول أو الثاني، وليست أهدافًا شخصية.',
        'يذكر الإجماع أنه لمن هم دون 25 عامًا، إذا كان هدف HbA1c هو 7.5%، يُضبط هدف TIR عند 60% تقريبًا — راجع فريقك الصحي.',
      ]);
    case TargetProfile.olderOrHighRisk:
      return const TargetSet(TargetProfile.olderOrHighRisk, {
        MetricKey.timeInRange: TargetSpec(MetricKey.timeInRange, TargetComparator.greaterThan, 50, _t3),
        MetricKey.timeBelowRangeTotal: TargetSpec(MetricKey.timeBelowRangeTotal, TargetComparator.lessThan, 1, _t3),
        MetricKey.timeVeryHigh: TargetSpec(MetricKey.timeVeryHigh, TargetComparator.lessThan, 10, _t3),
        MetricKey.cv: TargetSpec(MetricKey.cv, TargetComparator.lessOrEqual, 36, _t2),
      }, [
        'أهداف مرجعية عامة لكبار السن أو الفئات الأعلى خطورة وفق الإجماع، وتحتاج إلى تخصيص من الفريق الصحي.',
      ]);
    case TargetProfile.pregnancy:
      return const TargetSet(TargetProfile.pregnancy, {}, [
        'تستخدم أهداف الحمل نطاقات سكر مختلفة (63–140 mg/dL) ولا يطبّقها التطبيق تلقائيًا. اطلبي الأهداف من فريقك الصحي.',
      ]);
    case TargetProfile.pediatric:
      return const TargetSet(TargetProfile.pediatric, {}, [
        'أهداف الأطفال واليافعين تُحدَّد مع الفريق الصحي ولا يطبّقها التطبيق تلقائيًا.',
      ]);
    case TargetProfile.unspecified:
      return const TargetSet(TargetProfile.unspecified, {}, [
        'لم تُحدَّد الفئة المرجعية، لذلك لا تُعرض أهداف عامة. يمكنك اختيارها من الملف الشخصي بعد التأكد مع فريقك الصحي.',
      ]);
  }
}
