import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const calc = CgmCalculator();
  final day = DateTime(2026, 10, 1);

  group('unit conversion', () {
    test('mg/dL ↔ mmol/L uses 18.0182', () {
      expect(toMgdl(10, GlucoseUnit.mmoll), closeTo(180.182, 1e-9));
      expect(toMmoll(180, GlucoseUnit.mgdl), closeTo(9.9899, 1e-4));
      expect(toMgdl(toMmoll(126, GlucoseUnit.mgdl), GlucoseUnit.mmoll), closeTo(126, 1e-9));
    });
    test('formatNumber trims zeros and rounds half away from zero', () {
      expect(formatNumber(7.0), '7');
      expect(formatNumber(6.25, decimals: 1), '6.3');
      expect(formatNumber(82.80), '82.8');
    });
  });

  group('GMI', () {
    test('Bergenstal formula in % and mmol/mol', () {
      expect(Gmi.percentFromMeanMgdl(150), closeTo(6.898, 1e-9));
      expect(Gmi.mmolMolFromMeanMmoll(8.0), closeTo(50.357, 1e-3));
    });
    test('consistency tolerance', () {
      expect(Gmi.isConsistent(reportedGmiPercent: 6.3, meanMgdl: 126), isTrue);
      expect(Gmi.isConsistent(reportedGmiPercent: 7.3, meanMgdl: 126), isFalse);
    });
  });

  group('range boundaries (consensus Table 2)', () {
    test('each boundary value falls in the documented band', () {
      final r = calc.compute(series(day, [53.9, 54, 69.9, 70, 180, 180.1, 250, 250.1]));
      expect(r.metrics[MetricKey.timeVeryLow]!.value, closeTo(12.5, 1e-9));
      expect(r.metrics[MetricKey.timeLow]!.value, closeTo(25, 1e-9));
      expect(r.metrics[MetricKey.timeInRange]!.value, closeTo(25, 1e-9));
      expect(r.metrics[MetricKey.timeHigh]!.value, closeTo(25, 1e-9));
      expect(r.metrics[MetricKey.timeVeryHigh]!.value, closeTo(12.5, 1e-9));
      expect(r.metrics[MetricKey.timeBelowRangeTotal]!.value, closeTo(37.5, 1e-9));
      expect(r.metrics[MetricKey.timeAboveRangeTotal]!.value, closeTo(37.5, 1e-9));
    });
  });

  group('statistics', () {
    test('mean, sample SD, CV and GMI', () {
      final r = calc.compute(series(day, [100, 200]));
      expect(r.metrics[MetricKey.meanGlucose]!.value, 150);
      expect(r.metrics[MetricKey.sd]!.value, closeTo(70.7107, 1e-4));
      expect(r.metrics[MetricKey.cv]!.value, closeTo(47.1405, 1e-4));
      expect(r.metrics[MetricKey.gmi]!.value, closeTo(6.898, 1e-9));
      expect(r.metrics[MetricKey.gmi]!.origin, ValueOrigin.calculatedFromReadings);
    });
    test('single reading: SD and CV unavailable, never zero', () {
      final r = calc.compute(series(day, [120]));
      expect(r.metrics[MetricKey.sd]!.value, isNull);
      expect(r.metrics[MetricKey.cv]!.status, VerificationStatus.unavailable);
    });
    test('empty input: everything unavailable and insufficient', () {
      final r = calc.compute(const []);
      expect(r.usedReadings, 0);
      expect(r.metrics.values.every((m) => m.value == null), isTrue);
      expect(r.quality.sufficient, isFalse);
    });
  });

  group('duplicates, invalid values and gaps', () {
    test('identical duplicates are dropped; conflicting ones keep the first', () {
      final t = DateTime(2026, 10, 1, 8);
      final r = calc.compute([
        GlucoseReading(t, 100),
        GlucoseReading(t, 100),
        GlucoseReading(t.add(const Duration(minutes: 5)), 110),
        GlucoseReading(t.add(const Duration(minutes: 5)), 300),
      ]);
      expect(r.usedReadings, 2);
      expect(r.quality.duplicateReadings, 1);
      expect(r.quality.conflictingDuplicates, 1);
      expect(r.metrics[MetricKey.meanGlucose]!.value, 105);
      expect(r.quality.reasonsAr.any((s) => s.contains('بنفس التوقيت')), isTrue);
    });
    test('unsorted input is sorted before processing', () {
      final r = calc.compute([GlucoseReading(DateTime(2026, 10, 1, 9), 200), GlucoseReading(DateTime(2026, 10, 1, 8), 100)]);
      expect(r.cleanedReadings.first.mgdl, 100);
    });
    test('out-of-range and NaN readings are excluded and counted', () {
      final r = calc.compute(series(day, [5, double.nan, 120, 700]));
      expect(r.usedReadings, 1);
      expect(r.quality.invalidReadings, 3);
    });
    test('gaps longer than 2 × interval are counted', () {
      final r = calc.compute([
        GlucoseReading(DateTime(2026, 10, 1, 8), 100),
        GlucoseReading(DateTime(2026, 10, 1, 8, 10), 100), // 10 min: not a gap
        GlucoseReading(DateTime(2026, 10, 1, 9, 10), 100), // 60 min: gap of 55
      ]);
      expect(r.quality.gapCount, 1);
      expect(r.quality.longestGapMinutes, 55);
    });
  });

  group('coverage and sufficiency', () {
    test('coverage is readings ÷ expected over the window', () {
      final r = calc.compute(series(day, List.filled(144, 120), stepMinutes: 10), window: ReportPeriod(day, day));
      expect(r.quality.coveragePercent, closeTo(50, 1e-9));
      expect(r.quality.sufficient, isFalse);
    });
    test('fewer than 14 days is insufficient even at full coverage', () {
      final r = calc.compute(series(day, List.filled(288 * 7, 120)));
      expect(r.quality.daysOfData, 7);
      expect(r.quality.coveragePercent, closeTo(100, 1e-9));
      expect(r.quality.sufficient, isFalse);
      expect(r.quality.reasonsAr.first, contains('14'));
    });
    test('14 days at ≥70 % coverage is sufficient', () {
      final r = calc.compute(series(day, List.filled(288 * 14, 120)));
      expect(r.quality.daysOfData, 14);
      expect(r.quality.sufficient, isTrue);
    });
    test('readings outside the window are ignored', () {
      final r = calc.compute(series(day, List.filled(288 * 3, 120)), window: ReportPeriod(day.add(const Duration(days: 1)), day.add(const Duration(days: 1))));
      expect(r.usedReadings, 288);
    });
  });

  group('low episodes (≥ 15 min below 54)', () {
    final t0 = DateTime(2026, 10, 1, 2);
    test('three consecutive 5-min readings = 15 min counts', () {
      final e = calc.detectEpisodesBelow(series(t0, [100, 50, 50, 50, 100]), 54);
      expect(e, hasLength(1));
      expect(e.single.durationMinutes, 15);
      expect(e.single.nadirMgdl, 50);
    });
    test('two readings (10 min) do not count', () {
      expect(calc.detectEpisodesBelow(series(t0, [100, 50, 50, 100]), 54), isEmpty);
    });
    test('runs are not bridged across a data gap', () {
      final rs = [
        GlucoseReading(t0, 50),
        GlucoseReading(t0.add(const Duration(minutes: 5)), 50),
        GlucoseReading(t0.add(const Duration(minutes: 30)), 50),
        GlucoseReading(t0.add(const Duration(minutes: 35)), 50),
      ];
      expect(calc.detectEpisodesBelow(rs, 54), isEmpty);
    });
    test('runs separated by < 15 min above threshold merge into one episode', () {
      final e = calc.detectEpisodesBelow(series(t0, [50, 50, 50, 80, 50, 50, 50]), 54);
      expect(e, hasLength(1));
      expect(e.single.durationMinutes, 35);
    });
    test('runs separated by ≥ 15 min above threshold are separate', () {
      final e = calc.detectEpisodesBelow(series(t0, [50, 50, 50, 80, 80, 80, 80, 50, 50, 50]), 54);
      expect(e, hasLength(2));
    });
  });

  group('summary checks and derived metrics', () {
    test('consistent printed summary passes all checks', () {
      final checks = runSummaryChecks({
        MetricKey.timeVeryLow: 2,
        MetricKey.timeLow: 3.4,
        MetricKey.timeInRange: 82.8,
        MetricKey.timeHigh: 10.3,
        MetricKey.timeVeryHigh: 1.5,
        MetricKey.timeBelowRangeTotal: 5.4,
        MetricKey.timeAboveRangeTotal: 11.8,
        MetricKey.meanGlucose: 126,
        MetricKey.gmi: 6.3,
        MetricKey.cv: 35.1,
        MetricKey.sd: 44.1,
      });
      expect(checks.every((c) => c.passed == true), isTrue);
      expect(checks, hasLength(6));
    });
    test('band sum far from 100 fails', () {
      final checks = runSummaryChecks({
        MetricKey.timeVeryLow: 2,
        MetricKey.timeLow: 3,
        MetricKey.timeInRange: 70,
        MetricKey.timeHigh: 10,
        MetricKey.timeVeryHigh: 1,
      });
      expect(checks.firstWhere((c) => c.id == 'band_sum').passed, isFalse);
    });
    test('missing values make a check unevaluable (null), not passed', () {
      final checks = runSummaryChecks({MetricKey.timeInRange: 70});
      expect(checks.firstWhere((c) => c.id == 'band_sum').passed, isNull);
    });
    test('totals and GMI are derived only from verified values', () {
      final r = summaryReport(values: {MetricKey.timeVeryLow: 1, MetricKey.timeLow: 2, MetricKey.meanGlucose: 154});
      expect(r.metrics[MetricKey.timeBelowRangeTotal]!.value, 3);
      expect(r.metrics[MetricKey.timeBelowRangeTotal]!.origin, ValueOrigin.calculatedFromMetrics);
      expect(r.metrics[MetricKey.gmi]!.value, closeTo(3.31 + 0.02392 * 154, 1e-9));
      expect(r.metrics.containsKey(MetricKey.timeAboveRangeTotal), isFalse);
    });
  });
}
