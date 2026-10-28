import 'dart:math' as math;

import '../common/units.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import 'gmi.dart';

/// A run of consecutive readings below a threshold.
class GlucoseEpisode {
  const GlucoseEpisode({required this.start, required this.end, required this.durationMinutes, required this.nadirMgdl});
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final double nadirMgdl;
}

class CgmComputation {
  const CgmComputation({
    required this.metrics,
    required this.quality,
    required this.period,
    required this.usedReadings,
    required this.episodesBelow54,
    required this.cleanedReadings,
  });

  final Map<MetricKey, MetricValue> metrics;
  final DataQuality quality;
  final ReportPeriod? period;
  final int usedReadings;
  final List<GlucoseEpisode> episodesBelow54;
  final List<GlucoseReading> cleanedReadings;
}

/// Deterministic CGM metric calculation from raw readings.
///
/// Policy (documented in docs/METRICS.md):
/// * Readings outside [minValidMgdl, maxValidMgdl] are excluded and counted.
/// * Readings with identical timestamps: identical values are dropped as
///   duplicates; differing values keep the first reading in input order and
///   are counted as conflicts (reported as a data-quality warning).
/// * Percent-in-range values are count-based: each reading has equal weight.
///   With regular sampling this approximates time-weighting.
/// * Coverage = unique valid readings ÷ expected readings in the window
///   (window minutes ÷ sampling interval), capped at 100 %.
/// * A gap is any interval between consecutive readings longer than
///   2 × sampling interval.
/// * SD is the sample standard deviation (n − 1); CV = SD ÷ mean × 100.
/// * Range boundaries (mg/dL): very low < 54; low 54 to < 70;
///   in range 70–180 inclusive; high > 180 to 250 inclusive; very high > 250.
class CgmCalculator {
  const CgmCalculator({this.expectedIntervalMinutes = 5, this.minValidMgdl = 20, this.maxValidMgdl = 600, this.episodeMinMinutes = 15});

  final int expectedIntervalMinutes;
  final double minValidMgdl;
  final double maxValidMgdl;
  final int episodeMinMinutes;

  CgmComputation compute(List<GlucoseReading> input, {ReportPeriod? window}) {
    var invalid = 0;
    final indexed = <(int, GlucoseReading)>[];
    for (var i = 0; i < input.length; i++) {
      final r = input[i];
      if (r.mgdl.isNaN || r.mgdl.isInfinite || r.mgdl < minValidMgdl || r.mgdl > maxValidMgdl) {
        invalid++;
        continue;
      }
      if (window != null) {
        final d = dateOnly(r.timestamp);
        if (d.isBefore(window.start) || d.isAfter(window.end)) continue;
      }
      indexed.add((i, r));
    }
    // Stable sort by timestamp, then original index.
    indexed.sort((a, b) {
      final c = a.$2.timestamp.compareTo(b.$2.timestamp);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

    var duplicates = 0;
    var conflicts = 0;
    final cleaned = <GlucoseReading>[];
    for (final (_, r) in indexed) {
      if (cleaned.isNotEmpty && cleaned.last.timestamp.isAtSameMomentAs(r.timestamp)) {
        if (cleaned.last.mgdl == r.mgdl) {
          duplicates++;
        } else {
          conflicts++;
        }
        continue;
      }
      cleaned.add(r);
    }

    final reasons = <String>[];
    if (cleaned.isEmpty) {
      reasons.add('لا توجد قراءات صالحة للحساب.');
      return CgmComputation(
        metrics: {for (final k in MetricKey.values) k: _unavailable(k)},
        quality: DataQuality(
          daysOfData: window?.days,
          coveragePercent: window == null ? null : 0,
          coverageSource: 'محسوبة من القراءات',
          sufficient: false,
          reasonsAr: reasons,
          duplicateReadings: duplicates,
          conflictingDuplicates: conflicts,
          invalidReadings: invalid,
        ),
        period: window,
        usedReadings: 0,
        episodesBelow54: const [],
        cleanedReadings: const [],
      );
    }

    final period = window ?? ReportPeriod(cleaned.first.timestamp, cleaned.last.timestamp);
    final windowMinutes = period.days * 24 * 60;
    final expected = windowMinutes / expectedIntervalMinutes;
    final coverage = math.min(100.0, cleaned.length / expected * 100);

    var gapCount = 0;
    var longestGap = 0;
    for (var i = 1; i < cleaned.length; i++) {
      final diff = cleaned[i].timestamp.difference(cleaned[i - 1].timestamp).inMinutes;
      if (diff > 2 * expectedIntervalMinutes) {
        gapCount++;
        longestGap = math.max(longestGap, diff - expectedIntervalMinutes);
      }
    }

    final n = cleaned.length;
    var sum = 0.0;
    var veryLow = 0, low = 0, inRange = 0, high = 0, veryHigh = 0;
    for (final r in cleaned) {
      final v = r.mgdl;
      sum += v;
      if (v < 54) {
        veryLow++;
      } else if (v < 70) {
        low++;
      } else if (v <= 180) {
        inRange++;
      } else if (v <= 250) {
        high++;
      } else {
        veryHigh++;
      }
    }
    final mean = sum / n;
    double? sd;
    if (n >= 2) {
      var ss = 0.0;
      for (final r in cleaned) {
        ss += (r.mgdl - mean) * (r.mgdl - mean);
      }
      sd = math.sqrt(ss / (n - 1));
    }
    double pct(int c) => c / n * 100;

    MetricValue calc(MetricKey k, double? v, String unit) => v == null
        ? _unavailable(k)
        : MetricValue(key: k, value: v, unit: unit, origin: ValueOrigin.calculatedFromReadings, status: VerificationStatus.verified);

    final metrics = <MetricKey, MetricValue>{
      MetricKey.meanGlucose: calc(MetricKey.meanGlucose, mean, 'mg/dL'),
      MetricKey.gmi: calc(MetricKey.gmi, Gmi.percentFromMeanMgdl(mean), '%'),
      MetricKey.sd: calc(MetricKey.sd, sd, 'mg/dL'),
      MetricKey.cv: calc(MetricKey.cv, sd == null ? null : sd / mean * 100, '%'),
      MetricKey.timeVeryLow: calc(MetricKey.timeVeryLow, pct(veryLow), '%'),
      MetricKey.timeLow: calc(MetricKey.timeLow, pct(low), '%'),
      MetricKey.timeInRange: calc(MetricKey.timeInRange, pct(inRange), '%'),
      MetricKey.timeHigh: calc(MetricKey.timeHigh, pct(high), '%'),
      MetricKey.timeVeryHigh: calc(MetricKey.timeVeryHigh, pct(veryHigh), '%'),
      MetricKey.timeBelowRangeTotal: calc(MetricKey.timeBelowRangeTotal, pct(veryLow + low), '%'),
      MetricKey.timeAboveRangeTotal: calc(MetricKey.timeAboveRangeTotal, pct(high + veryHigh), '%'),
      MetricKey.sensorActive: calc(MetricKey.sensorActive, coverage, '%'),
    };

    if (period.days < DataQuality.minDays) {
      reasons.add('مدة البيانات ${period.days} يومًا، والتوصية العامة 14 يومًا على الأقل.');
    }
    if (coverage < DataQuality.minCoveragePercent) {
      reasons.add('تغطية الحساس ${formatNumber(coverage)}%، والتوصية العامة 70% على الأقل.');
    }
    if (conflicts > 0) {
      reasons.add('وُجدت $conflicts قراءة بنفس التوقيت وبقيم مختلفة؛ احتُفظ بالأولى فقط.');
    }

    return CgmComputation(
      metrics: metrics,
      quality: DataQuality(
        daysOfData: period.days,
        coveragePercent: coverage,
        coverageSource: 'محسوبة من القراءات (فاصل متوقع $expectedIntervalMinutes دقائق)',
        sufficient: period.days >= DataQuality.minDays && coverage >= DataQuality.minCoveragePercent,
        reasonsAr: reasons,
        duplicateReadings: duplicates,
        conflictingDuplicates: conflicts,
        invalidReadings: invalid,
        gapCount: gapCount,
        longestGapMinutes: longestGap,
      ),
      period: period,
      usedReadings: n,
      episodesBelow54: detectEpisodesBelow(cleaned, 54),
      cleanedReadings: cleaned,
    );
  }

  /// Episodes of readings below [thresholdMgdl] lasting at least
  /// [episodeMinMinutes]. Approximates the 2017 consensus episode definition
  /// (≥ 15 min below to start; ≥ 15 min above to end):
  /// * runs are never bridged across a data gap (> 2 × interval);
  /// * runs separated by < 15 min of readings at/above the threshold are merged;
  /// * a merged episode counts only if one of its runs lasted ≥ 15 min.
  /// Input must be sorted and de-duplicated (as produced by [compute]).
  List<GlucoseEpisode> detectEpisodesBelow(List<GlucoseReading> sorted, double thresholdMgdl) {
    final maxGap = 2 * expectedIntervalMinutes;
    final runs = <_Run>[];
    _Run? current;
    GlucoseReading? prev;
    for (final r in sorted) {
      final gapBefore = prev != null && r.timestamp.difference(prev.timestamp).inMinutes > maxGap;
      if (r.mgdl < thresholdMgdl) {
        if (current == null || gapBefore) {
          if (current != null) runs.add(current);
          current = _Run(r.timestamp, r.timestamp, r.mgdl, gapBefore: gapBefore || current != null);
        } else {
          current.end = r.timestamp;
          current.nadir = math.min(current.nadir, r.mgdl);
        }
      } else {
        if (current != null) {
          runs.add(current);
          current = null;
        }
        if (gapBefore && runs.isNotEmpty) runs.last.gapAfter = true;
      }
      prev = r;
    }
    if (current != null) runs.add(current);

    int dur(_Run x) => x.end.difference(x.start).inMinutes + expectedIntervalMinutes;

    final merged = <_Merged>[];
    for (final run in runs) {
      if (merged.isNotEmpty) {
        final last = merged.last;
        final aboveMinutes = run.start.difference(last.end).inMinutes - expectedIntervalMinutes;
        if (!last.gapAfter && !run.gapBefore && aboveMinutes < episodeMinMinutes) {
          last.end = run.end;
          last.nadir = math.min(last.nadir, run.nadir);
          last.hasQualifyingRun = last.hasQualifyingRun || dur(run) >= episodeMinMinutes;
          last.gapAfter = run.gapAfter;
          continue;
        }
      }
      merged.add(_Merged(run.start, run.end, run.nadir, dur(run) >= episodeMinMinutes, run.gapAfter));
    }
    return [
      for (final m in merged)
        if (m.hasQualifyingRun)
          GlucoseEpisode(
            start: m.start,
            end: m.end,
            durationMinutes: m.end.difference(m.start).inMinutes + expectedIntervalMinutes,
            nadirMgdl: m.nadir,
          ),
    ];
  }

  static MetricValue _unavailable(MetricKey k) => MetricValue(
        key: k,
        value: null,
        unit: k.isPercent || k == MetricKey.gmi ? '%' : 'mg/dL',
        origin: ValueOrigin.calculatedFromReadings,
        status: VerificationStatus.unavailable,
      );
}

class _Run {
  _Run(this.start, this.end, this.nadir, {this.gapBefore = false});
  DateTime start;
  DateTime end;
  double nadir;
  bool gapBefore;
  bool gapAfter = false;
}

class _Merged {
  _Merged(this.start, this.end, this.nadir, this.hasQualifyingRun, this.gapAfter);
  DateTime start;
  DateTime end;
  double nadir;
  bool hasQualifyingRun;
  bool gapAfter;
}
