import 'dart:math' as math;

import '../common/units.dart';
import '../models/cgm.dart';

/// Deterministic pseudo-random generator (LCG) so demo data and tests are
/// reproducible on every platform.
class Lcg {
  Lcg(this._state);
  int _state;
  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

/// SYNTHETIC CGM readings for the demo. Not derived from any real person or
/// from the AZT1D dataset. 5-minute sampling over [days] days starting at
/// [startDay] with a daily pattern, meal peaks, three injected low episodes,
/// two data gaps, random dropouts and two exact duplicate rows.
List<GlucoseReading> syntheticReadings({required DateTime startDay, int days = 14, int seed = 42}) {
  final rnd = Lcg(seed);
  final out = <GlucoseReading>[];
  final start = dateOnly(startDay);
  var drift = 0.0;
  for (var i = 0; i < days * 288; i++) {
    final t = start.add(Duration(minutes: 5 * i));
    final day = i ~/ 288;
    final h = (i % 288) * 5 / 60.0;
    // Gaps: day 5 10:00–12:00 (signal loss), day 9 06:00–08:00 (warm-up).
    if ((day == 5 && h >= 10 && h < 12) || (day == 9 && h >= 6 && h < 8)) continue;
    if (rnd.next() < 0.03) continue; // random dropouts
    drift = drift * 0.97 + (rnd.next() - 0.5) * 6;
    double bump(double center, double amp) => amp * math.exp(-math.pow(h - center, 2) / (2 * 0.9 * 0.9));
    var g = 128 + 18 * math.sin(2 * math.pi * (h - 9) / 24) + bump(8.3, 78) + bump(14, 70) + bump(20.5, 92) + drift * 4;
    if (day % 4 == 1) g += bump(22.5, 60); // occasional late-evening highs
    // Injected lows (minutes below 54): day 2 03:00 for 30 min,
    // day 7 02:30 for 25 min, day 11 16:00 for 20 min.
    bool inWindow(int d, double from, int minutes) => day == d && h >= from && h < from + minutes / 60.0;
    if (inWindow(2, 3.0, 30) || inWindow(7, 2.5, 25) || inWindow(11, 16.0, 20)) {
      g = 47 + rnd.next() * 5;
    } else if (inWindow(2, 2.6, 24) || inWindow(7, 2.1, 24) || inWindow(11, 15.6, 24) || inWindow(4, 4.0, 40)) {
      g = 58 + rnd.next() * 10;
    }
    g = g.clamp(40, 400).toDouble();
    out.add(GlucoseReading(t, roundTo(g, 0)));
    if (day == 3 && i % 288 == 100) out.add(GlucoseReading(t, roundTo(g, 0))); // exact duplicate
    if (day == 12 && i % 288 == 40) out.add(GlucoseReading(t, roundTo(g, 0))); // exact duplicate
  }
  return out;
}

/// Values for a synthetic report rendered in the Omnipod Discover summary
/// layout. Percent bands must sum to ~100.
class SyntheticSummaryValues {
  const SyntheticSummaryValues({
    required this.meanMgdl,
    required this.gmi,
    required this.cv,
    required this.sd,
    required this.connectedSensor,
    required this.veryLow,
    required this.low,
    required this.inRange,
    required this.high,
    required this.veryHigh,
  });
  final double meanMgdl, gmi, cv, sd, connectedSensor, veryLow, low, inRange, high, veryHigh;
}

const demoReportAValues = SyntheticSummaryValues(
  meanMgdl: 172, gmi: 7.4, cv: 38.2, sd: 65.7, connectedSensor: 91,
  veryLow: 0.6, low: 2.4, inRange: 62, high: 27, veryHigh: 8,
);

const demoUploadValues = SyntheticSummaryValues(
  meanMgdl: 168, gmi: 7.3, cv: 39.5, sd: 66.4, connectedSensor: 88,
  veryLow: 1.4, low: 3.1, inRange: 65.5, high: 23, veryHigh: 7,
);

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _p(double v) => formatNumber(v);

/// Text lines of a SYNTHETIC summary page that follows the line order PDFium
/// produced for the supplied Omnipod Discover report (layout only). Contains
/// no personal data. Used for demo fixtures, the in-app demo PDF and tests.
List<String> syntheticDiscoverSummaryLines({
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime generated,
  required SyntheticSummaryValues v,
  DateTime? sensorFrom,
  DateTime? sensorTo,
}) {
  final days = daysBetween(periodStart, periodEnd) + 1;
  final tbr = v.veryLow + v.low, tar = v.high + v.veryHigh;
  return [
    'SYNTHETIC DEMO REPORT - not a real patient',
    'Demo Patient',
    '$days-Day Summary',
    '${_d(periodStart)}–${_d(periodEnd)} | Report Generated: ${_d(generated)}',
    'AGP Report - Developed By HealthPartners Institute d/b/a International Diabetes Center',
    if (sensorFrom != null && sensorTo != null)
      'Sensor data is only available from ${_d(sensorFrom)}–${_d(sensorTo)}. Time in Ranges, Glucose Metrics and AGP are calculated based on data within this timeframe.',
    'Time in Ranges',
    'Goal: <4%',
    'Goal: >70%',
    'Goal: <25%',
    'Glucose Metrics',
    'Average Glucose',
    '${_p(v.meanMgdl)} mg/dL',
    'Glucose Mgmt Indicator (GMI)',
    '${_p(v.gmi)}%',
    'Glucose Variability (CV*)',
    '${_p(v.cv)}%',
    '*Coefficient of variation',
    'Standard Deviation (SD)',
    '${_p(v.sd)} mg/dL',
    'Device Use | Omnipod® 5 & Dexcom G7',
    'Connected Sensor Time ${_p(v.connectedSensor)}%',
    'Page 1 (of 1)',
    'Goal: <1%',
    '<54 mg/dL',
    '${_p(v.veryLow)}% Very Low',
    '70-180 mg/dL',
    'Time in Range',
    'Goal: <5%',
    '>250 mg/dL',
    '${_p(v.veryHigh)}% Very High',
    '54-69 mg/dL',
    '${_p(v.low)}% Low',
    '181-250 mg/dL',
    '${_p(v.high)}% High',
    '${_p(tbr)}% ${_p(v.inRange)}% ${_p(tar)}%',
    'Goal: <7%',
    'Goal: ≤36%',
  ];
}
