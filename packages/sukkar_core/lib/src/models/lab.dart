import 'enums.dart';

/// Laboratory tests with first-class handling. Other tests use [LabTestCode.other]
/// with a free-text name; the app does not interpret them automatically.
enum LabTestCode { hba1c, fastingPlasmaGlucose, creatinine, egfr, ldl, uacr, other }

extension LabTestCodeInfo on LabTestCode {
  String get labelAr => switch (this) {
        LabTestCode.hba1c => 'السكر التراكمي (HbA1c)',
        LabTestCode.fastingPlasmaGlucose => 'سكر صائم (مختبر)',
        LabTestCode.creatinine => 'الكرياتينين',
        LabTestCode.egfr => 'معدل الترشيح الكبيبي (eGFR)',
        LabTestCode.ldl => 'الكوليسترول الضار (LDL)',
        LabTestCode.uacr => 'نسبة الألبومين إلى الكرياتينين في البول (UACR)',
        LabTestCode.other => 'تحليل آخر',
      };

  /// Units suggested in the entry form. The user can still type a unit for
  /// [LabTestCode.other]; no conversion is applied to non-HbA1c tests.
  List<String> get suggestedUnits => switch (this) {
        LabTestCode.hba1c => const ['%', 'mmol/mol'],
        LabTestCode.fastingPlasmaGlucose => const ['mg/dL', 'mmol/L'],
        LabTestCode.creatinine => const ['mg/dL', 'µmol/L'],
        LabTestCode.egfr => const ['mL/min/1.73m²'],
        LabTestCode.ldl => const ['mg/dL', 'mmol/L'],
        LabTestCode.uacr => const ['mg/g', 'mg/mmol'],
        LabTestCode.other => const [],
      };
}

enum LabSource { manual, extracted, futureIntegration }

extension LabSourceAr on LabSource {
  String get labelAr => switch (this) {
        LabSource.manual => 'إدخال يدوي',
        LabSource.extracted => 'مستخرج من ملف',
        LabSource.futureIntegration => 'تكامل مستقبلي',
      };
}

/// Reference interval as printed by the laboratory. This is laboratory-specific
/// and is shown verbatim; it is not a clinical treatment target.
class ReferenceInterval {
  const ReferenceInterval({this.low, this.high, this.text});
  final double? low;
  final double? high;
  final String? text;

  bool get isEmpty => low == null && high == null && (text == null || text!.trim().isEmpty);

  String describe(String unit) {
    if (text != null && text!.trim().isNotEmpty) return text!.trim();
    if (low != null && high != null) return '$low–$high $unit';
    if (low != null) return '≥ $low $unit';
    if (high != null) return '≤ $high $unit';
    return '';
  }
}

class LabResult {
  const LabResult({
    required this.id,
    required this.userId,
    required this.testCode,
    required this.testName,
    required this.value,
    required this.unit,
    required this.collectionDate,
    required this.source,
    required this.verification,
    required this.provenance,
    required this.createdAt,
    this.referenceInterval,
    this.labName,
    this.linkedReminderId,
  });

  final String id;
  final String userId;
  final LabTestCode testCode;
  final String testName;
  final double value;
  final String unit;

  /// Null when the user does not know the date. Undated results are never
  /// used in time-based comparisons.
  final DateTime? collectionDate;
  final LabSource source;
  final VerificationStatus verification;
  final DataProvenance provenance;
  final DateTime createdAt;
  final ReferenceInterval? referenceInterval;
  final String? labName;
  final String? linkedReminderId;

  bool get isVerified => verification == VerificationStatus.verified;

  LabResult copyWith({VerificationStatus? verification, String? linkedReminderId}) => LabResult(
        id: id,
        userId: userId,
        testCode: testCode,
        testName: testName,
        value: value,
        unit: unit,
        collectionDate: collectionDate,
        source: source,
        verification: verification ?? this.verification,
        provenance: provenance,
        createdAt: createdAt,
        referenceInterval: referenceInterval,
        labName: labName,
        linkedReminderId: linkedReminderId ?? this.linkedReminderId,
      );
}
