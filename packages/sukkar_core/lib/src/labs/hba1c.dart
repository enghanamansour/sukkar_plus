import '../common/units.dart';
import '../models/enums.dart';
import '../models/lab.dart';

enum HbA1cUnit { percent, mmolMol }

HbA1cUnit? parseHbA1cUnit(String unit) {
  final u = unit.trim().toLowerCase().replaceAll(' ', '');
  if (u == '%' || u == 'percent' || u == 'ngsp%') return HbA1cUnit.percent;
  if (u == 'mmol/mol' || u == 'ifcc') return HbA1cUnit.mmolMol;
  return null;
}

/// HbA1c unit conversion using the IFCC–NGSP master equation:
/// NGSP (%) = 0.09148 × IFCC (mmol/mol) + 2.152, i.e.
/// IFCC = (NGSP − 2.152) / 0.09148. See SOURCE_MAPPING.md.
class HbA1c {
  static double percentToMmolMol(double percent) => (percent - 2.152) / 0.09148;
  static double mmolMolToPercent(double mmolMol) => 0.09148 * mmolMol + 2.152;

  /// Plausibility bounds for data entry (not clinical thresholds).
  static const minPercent = 3.0, maxPercent = 20.0;
  static const minMmolMol = 9.0, maxMmolMol = 195.0;

  static double toPercent(double value, HbA1cUnit unit) => unit == HbA1cUnit.percent ? value : mmolMolToPercent(value);
}

class LabValidationIssue {
  const LabValidationIssue(this.field, this.messageAr);
  final String field;
  final String messageAr;
}

/// Validates a laboratory entry before it is saved.
List<LabValidationIssue> validateLabEntry({
  required LabTestCode code,
  required String testName,
  required double? value,
  required String unit,
  required DateTime? collectionDate,
  required DateTime now,
  ReferenceInterval? referenceInterval,
}) {
  final issues = <LabValidationIssue>[];
  if (code == LabTestCode.other && testName.trim().isEmpty) {
    issues.add(const LabValidationIssue('testName', 'أدخل اسم التحليل.'));
  }
  if (value == null || !value.isFinite) {
    issues.add(const LabValidationIssue('value', 'أدخل قيمة رقمية صحيحة.'));
  } else if (value < 0) {
    issues.add(const LabValidationIssue('value', 'لا يمكن أن تكون القيمة سالبة.'));
  }
  if (unit.trim().isEmpty) {
    issues.add(const LabValidationIssue('unit', 'حدّد وحدة القياس.'));
  }
  if (code == LabTestCode.hba1c && value != null && value.isFinite) {
    final u = parseHbA1cUnit(unit);
    if (u == null) {
      issues.add(const LabValidationIssue('unit', 'وحدة HbA1c يجب أن تكون % أو mmol/mol.'));
    } else if (u == HbA1cUnit.percent && (value < HbA1c.minPercent || value > HbA1c.maxPercent)) {
      issues.add(const LabValidationIssue('value', 'قيمة HbA1c بالنسبة المئوية غير معقولة (المتوقع بين 3 و20). تأكد من الوحدة.'));
    } else if (u == HbA1cUnit.mmolMol && (value < HbA1c.minMmolMol || value > HbA1c.maxMmolMol)) {
      issues.add(const LabValidationIssue('value', 'قيمة HbA1c بوحدة mmol/mol غير معقولة (المتوقع بين 9 و195). تأكد من الوحدة.'));
    }
  }
  if (collectionDate != null && daysBetween(now, collectionDate) > 0) {
    issues.add(const LabValidationIssue('collectionDate', 'تاريخ سحب العينة لا يمكن أن يكون في المستقبل.'));
  }
  final ri = referenceInterval;
  if (ri != null && ri.low != null && ri.high != null && ri.low! > ri.high!) {
    issues.add(const LabValidationIssue('referenceInterval', 'الحد الأدنى للمرجع أكبر من الحد الأعلى.'));
  }
  return issues;
}

/// HbA1c results that may be used for dated comparisons: verified, dated and
/// in a recognised unit, sorted oldest → newest.
List<LabResult> comparableHbA1c(Iterable<LabResult> labs) {
  final out = labs
      .where((l) => l.testCode == LabTestCode.hba1c && l.isVerified && l.collectionDate != null && parseHbA1cUnit(l.unit) != null)
      .toList()
    ..sort((a, b) => a.collectionDate!.compareTo(b.collectionDate!));
  return out;
}

String hba1cDisplay(LabResult r) {
  final u = parseHbA1cUnit(r.unit);
  if (u == HbA1cUnit.mmolMol) {
    return '${formatNumber(r.value)} mmol/mol (≈ ${formatNumber(HbA1c.mmolMolToPercent(r.value))}%)';
  }
  return '${formatNumber(r.value)}%';
}

extension LabVerificationShortcut on LabResult {
  bool get usableForComparison => verification == VerificationStatus.verified && collectionDate != null;
}
