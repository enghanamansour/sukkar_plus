/// Glucose Management Indicator.
///
/// Source: Bergenstal RM et al. "Glucose Management Indicator (GMI): a new term
/// for estimating A1C from continuous glucose monitoring." Diabetes Care
/// 2018;41:2275–2280 (reference 75 of the supplied consensus paper; the
/// formula itself is not printed in the supplied files — see SOURCE_MAPPING.md).
library;

class Gmi {
  /// GMI (%) = 3.31 + 0.02392 × mean glucose (mg/dL).
  static double percentFromMeanMgdl(double meanMgdl) => 3.31 + 0.02392 * meanMgdl;

  /// GMI (mmol/mol) = 12.71 + 4.70587 × mean glucose (mmol/L).
  static double mmolMolFromMeanMmoll(double meanMmoll) => 12.71 + 4.70587 * meanMmoll;

  /// Tolerance used when checking a printed GMI against a printed mean.
  /// Printed GMI is rounded to 0.1 and printed mean to 1 mg/dL.
  static const consistencyTolerancePercent = 0.15;

  static bool isConsistent({required double reportedGmiPercent, required double meanMgdl}) =>
      (reportedGmiPercent - percentFromMeanMgdl(meanMgdl)).abs() <= consistencyTolerancePercent;
}
