/// Shared enums that describe where data came from and how trustworthy it is.
/// These distinctions are surfaced in the UI on every value.
library;

/// Whether a record is real user data or synthetic demo data.
enum DataProvenance { real, synthetic }

/// How a single value was obtained.
enum ValueOrigin {
  /// Read from a device report (local text extraction and/or AI extraction).
  extractedFromReport,

  /// Computed deterministically from raw CGM readings.
  calculatedFromReadings,

  /// Computed deterministically from other verified metrics (e.g. TBR total
  /// = low band + very-low band, or GMI from mean glucose).
  calculatedFromMetrics,

  /// An extracted value the user corrected; the original is preserved.
  userCorrected,

  /// Typed in by the user (e.g. a laboratory result).
  userEntered,
}

/// Verification state of a value before it may be used in comparisons,
/// rules or summaries. Only [verified] values are used downstream.
enum VerificationStatus { verified, needsReview, unavailable, rejected }

enum UserRole { patient, reviewer }

/// Population context used to decide whether general consensus targets may be
/// displayed. The app never infers this; the user selects it (ideally after
/// confirming with their care team).
enum TargetProfile {
  /// Consensus Table 3: adults with type 1 / type 2 diabetes.
  generalAdultT1T2,

  /// Consensus Table 3: older and/or high-risk individuals.
  olderOrHighRisk,

  /// Pregnancy: consensus Table 4 uses different ranges; not implemented.
  pregnancy,

  /// Children/adolescents: targets must be clinician-set.
  pediatric,

  /// Not selected.
  unspecified,
}

extension ValueOriginAr on ValueOrigin {
  String get labelAr => switch (this) {
        ValueOrigin.extractedFromReport => 'مستخرج من التقرير',
        ValueOrigin.calculatedFromReadings => 'محسوب من القراءات',
        ValueOrigin.calculatedFromMetrics => 'محسوب من مؤشرات موثّقة',
        ValueOrigin.userCorrected => 'مصحّح يدويًا',
        ValueOrigin.userEntered => 'مُدخل يدويًا',
      };
}

extension VerificationStatusAr on VerificationStatus {
  String get labelAr => switch (this) {
        VerificationStatus.verified => 'موثّق',
        VerificationStatus.needsReview => 'يحتاج تحقق',
        VerificationStatus.unavailable => 'غير متاح',
        VerificationStatus.rejected => 'مرفوض',
      };
}

extension TargetProfileAr on TargetProfile {
  String get labelAr => switch (this) {
        TargetProfile.generalAdultT1T2 => 'بالغ مصاب بالسكري من النوع الأول أو الثاني (أهداف عامة)',
        TargetProfile.olderOrHighRisk => 'كبار السن أو الفئات الأعلى خطورة',
        TargetProfile.pregnancy => 'حمل',
        TargetProfile.pediatric => 'أطفال ويافعون',
        TargetProfile.unspecified => 'لم يُحدَّد',
      };
}

extension DataProvenanceAr on DataProvenance {
  String get labelAr => this == DataProvenance.synthetic ? 'بيانات تجريبية' : 'بيانات المستخدم';
}
