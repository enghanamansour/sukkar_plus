import '../cgm/summary_checks.dart';
import '../common/units.dart';
import '../models/cgm.dart';
import 'extraction_models.dart';

/// Deterministic, local extraction of summary metrics from the text of a CGM
/// report PDF (text obtained with PDFium on device, or any extractor).
///
/// Supported layouts:
/// * `omnipod_discover_agp_summary_v1` — the "N-Day Summary" page of the
///   Omnipod Discover HCP report (Omnipod 5 & Dexcom G7). Verified against the
///   real report supplied for this project (layout only; no values from it are
///   stored in this repository).
/// * `generic_agp_unverified` — best-effort label search for other AGP-style
///   reports. Never verified against a real file; every value must be
///   confirmed individually by the user.
///
/// Personal data on the report (name, date of birth, serial numbers) is never
/// read into a field. Insulin, bolus, carbohydrate and pump-setting values are
/// deliberately ignored: Sukkar Plus does not work with dosing information.
class ReportTextParser {
  const ReportTextParser();

  static const discoverFormatId = 'omnipod_discover_agp_summary_v1';
  static const genericFormatId = 'generic_agp_unverified';

  ExtractionResult parse(List<String> pageTexts) {
    final pages = [for (final t in pageTexts) _lines(t)];
    final all = pages.expand((p) => p).join('\n');
    final isDiscover = all.contains('Glucose Mgmt Indicator') && all.contains('Time in Ranges');
    return isDiscover ? _parseDiscover(pages) : _parseGeneric(pages);
  }

  // ---------------------------------------------------------------- helpers

  static List<String> _lines(String t) => t
      .replaceAll(' ', ' ')
      .replaceAll('ﬁ', 'fi')
      .replaceAll('ﬂ', 'fl')
      .replaceAll('−', '-')
      .split(RegExp(r'\r?\n'))
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();

  static double? _num(String s) => double.tryParse(s.replaceAll(',', '.'));

  static final _pctLine = RegExp(r'^(\d{1,3}(?:[.,]\d+)?)\s*%$');
  static final _unitLine = RegExp(r'^(\d{1,3}(?:[.,]\d+)?)\s*(mg/dL|mmol/L)$', caseSensitive: false);
  static final _band = RegExp(r'^(\d{1,3}(?:\.\d+)?)\s*%\s+(Very Low|Low|Very High|High)$', caseSensitive: false);
  static final _triple = RegExp(r'^(\d{1,3}(?:\.\d+)?)%\s+(\d{1,3}(?:\.\d+)?)%\s+(\d{1,3}(?:\.\d+)?)%$');
  static final _slashRange = RegExp(r'(\d{2}/\d{2}/\d{4})\s*[–—-]\s*(\d{2}/\d{2}/\d{4})');

  static DateTime? _slashDate(String s, {required bool dayFirst}) {
    final p = s.split('/');
    if (p.length != 3) return null;
    final a = int.tryParse(p[0]), b = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (a == null || b == null || y == null) return null;
    final d = dayFirst ? a : b, m = dayFirst ? b : a;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    return (dt.month == m && dt.day == d) ? dt : null;
  }

  static ReportPeriod? _period(String a, String b, {required bool dayFirst}) {
    final s = _slashDate(a, dayFirst: dayFirst), e = _slashDate(b, dayFirst: dayFirst);
    if (s == null || e == null || e.isBefore(s)) return null;
    return ReportPeriod(s, e);
  }

  /// Value on one of the next [lookahead] lines after a label line.
  static (RegExpMatch, int)? _after(List<String> lines, int i, RegExp re, {int lookahead = 2}) {
    for (var j = i + 1; j <= i + lookahead && j < lines.length; j++) {
      final m = re.firstMatch(lines[j]);
      if (m != null) return (m, j);
    }
    return null;
  }

  // -------------------------------------------------- Omnipod Discover (v1)

  ExtractionResult _parseDiscover(List<List<String>> pages) {
    var summaryIdx = pages.indexWhere((p) => p.any((l) => l == 'Glucose Metrics') && p.any((l) => l == 'Time in Ranges'));
    if (summaryIdx < 0) summaryIdx = 0;
    final lines = pages[summaryIdx];
    final page = summaryIdx + 1;
    final warnings = <String>[];
    final raw = <MetricKey, (double, String)>{}; // value, source label
    final ambiguous = <MetricKey, String>{};
    var unit = GlucoseUnit.mgdl;
    int? reportDays;
    String? device;
    var limited = false;
    ExtractedPeriod reportPeriod = ExtractedPeriod.notFound;
    ExtractedPeriod metricsPeriod = ExtractedPeriod.notFound;
    String? reportA, reportB, sensorA, sensorB;

    final bands = <MetricKey, List<double>>{};
    final triples = <List<double>>[];

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final hdr = RegExp(r'^(\d{1,3})-Day Summary$').firstMatch(l);
      if (hdr != null) reportDays = int.parse(hdr.group(1)!);

      if (reportA == null && l.contains('Report Generated')) {
        final m = _slashRange.firstMatch(l);
        if (m != null) {
          reportA = m.group(1);
          reportB = m.group(2);
        }
      }
      if (l.startsWith('Sensor data is only available from')) {
        final m = _slashRange.firstMatch(l);
        if (m != null) {
          sensorA = m.group(1);
          sensorB = m.group(2);
        }
      }
      if (l.contains('limited or no data')) limited = true;
      if (l.startsWith('Device Use |')) {
        device = l.substring('Device Use |'.length).replaceAll('®', '').trim();
      }

      void next(MetricKey k, RegExp re, String label) {
        final r = _after(lines, i, re);
        if (r == null) return;
        final v = _num(r.$1.group(1)!);
        if (v == null) return;
        if (re == _unitLine) {
          final u = parseGlucoseUnit(r.$1.group(2)!);
          if (k == MetricKey.meanGlucose && u != null) unit = u;
        }
        raw[k] = (v, label);
      }

      switch (l) {
        case 'Average Glucose':
          next(MetricKey.meanGlucose, _unitLine, l);
        case 'Glucose Mgmt Indicator (GMI)':
          next(MetricKey.gmi, _pctLine, l);
        case 'Glucose Variability (CV*)':
          next(MetricKey.cv, _pctLine, l);
        case 'Standard Deviation (SD)':
          next(MetricKey.sd, _unitLine, l);
      }

      final cs = RegExp(r'^Connected Sensor Time\s+(\d{1,3}(?:\.\d+)?)\s*%$').firstMatch(l);
      if (cs != null) raw[MetricKey.sensorActive] = (_num(cs.group(1)!)!, 'Connected Sensor Time');

      final b = _band.firstMatch(l);
      if (b != null) {
        final name = b.group(2)!.toLowerCase();
        final key = switch (name) {
          'very low' => MetricKey.timeVeryLow,
          'low' => MetricKey.timeLow,
          'very high' => MetricKey.timeVeryHigh,
          _ => MetricKey.timeHigh,
        };
        bands.putIfAbsent(key, () => []).add(_num(b.group(1)!)!);
      }
      final t = _triple.firstMatch(l);
      if (t != null) triples.add([_num(t.group(1)!)!, _num(t.group(2)!)!, _num(t.group(3)!)!]);
    }

    const bandLabels = {
      MetricKey.timeVeryLow: 'Very Low (<54 mg/dL)',
      MetricKey.timeLow: 'Low (54-69 mg/dL)',
      MetricKey.timeHigh: 'High (181-250 mg/dL)',
      MetricKey.timeVeryHigh: 'Very High (>250 mg/dL)',
    };
    bands.forEach((k, vals) {
      if (vals.toSet().length == 1) {
        raw[k] = (vals.first, bandLabels[k]!);
      } else {
        ambiguous[k] = 'ظهرت للفئة أكثر من قيمة في الصفحة.';
      }
    });

    // The "Time in Range" percentage is printed without a label on the same
    // line as the TBR and TAR totals ("5.4% 82.8% 11.8%"). Accept a triple
    // only when it reconciles with the band values.
    final vl = raw[MetricKey.timeVeryLow]?.$1, lo = raw[MetricKey.timeLow]?.$1;
    final hi = raw[MetricKey.timeHigh]?.$1, vh = raw[MetricKey.timeVeryHigh]?.$1;
    final matching = triples.where((t) {
      final sumOk = ((t[0] + t[1] + t[2]) - 100).abs() <= SummaryTolerances.bandSum;
      final belowOk = vl == null || lo == null || (t[0] - (vl + lo)).abs() <= SummaryTolerances.totalVsBands;
      final aboveOk = hi == null || vh == null || (t[2] - (hi + vh)).abs() <= SummaryTolerances.totalVsBands;
      return sumOk && belowOk && aboveOk;
    }).toList();
    final bandsComplete = vl != null && lo != null && hi != null && vh != null;
    if (matching.length == 1) {
      final t = matching.single;
      const lbl = 'Time in Ranges summary row (below / in range / above)';
      raw[MetricKey.timeBelowRangeTotal] = (t[0], lbl);
      raw[MetricKey.timeInRange] = (t[1], 'Time in Range (70-180 mg/dL)');
      raw[MetricKey.timeAboveRangeTotal] = (t[2], lbl);
      if (!bandsComplete) {
        ambiguous[MetricKey.timeInRange] = 'قيمة الوقت ضمن النطاق مطبوعة دون عنوان، ولم يمكن مطابقتها مع جميع الفئات.';
      }
    } else if (matching.length > 1) {
      ambiguous[MetricKey.timeInRange] = 'وُجد أكثر من صف محتمل لقيمة الوقت ضمن النطاق.';
    } else {
      // No row reconciles with the bands. If exactly one row still sums to
      // ~100 %, keep it as ambiguous so the consistency checks can show the
      // user which printed values disagree, instead of silently dropping TIR.
      final sum100 = triples.where((t) => ((t[0] + t[1] + t[2]) - 100).abs() <= SummaryTolerances.bandSum).toList();
      if (sum100.length == 1) {
        final t = sum100.single;
        const lbl = 'Time in Ranges summary row (below / in range / above)';
        raw[MetricKey.timeBelowRangeTotal] = (t[0], lbl);
        raw[MetricKey.timeInRange] = (t[1], 'Time in Range (70-180 mg/dL)');
        raw[MetricKey.timeAboveRangeTotal] = (t[2], lbl);
        ambiguous[MetricKey.timeInRange] = 'صف الملخص لا يتطابق مع قيم الفئات المطبوعة؛ قارن القيم بالتقرير.';
      }
    }

    // Periods. The supplied report prints DD/MM/YYYY; we confirm the
    // orientation using the "N-Day Summary" header.
    var dayFirst = true;
    if (reportA != null && reportB != null) {
      final df = _period(reportA, reportB, dayFirst: true);
      final mf = _period(reportA, reportB, dayFirst: false);
      if (df != null && (reportDays == null || df.days == reportDays)) {
        reportPeriod = ExtractedPeriod(
          period: df,
          status: ExtractionStatus.found,
          sourceLabel: '$reportA–$reportB',
          page: page,
          noteAr: reportDays != null ? 'تطابق مع عنوان التقرير ($reportDays يومًا).' : null,
        );
      } else if (mf != null && reportDays != null && mf.days == reportDays) {
        dayFirst = false;
        reportPeriod = ExtractedPeriod(period: mf, status: ExtractionStatus.found, sourceLabel: '$reportA–$reportB', page: page, noteAr: 'تنسيق التاريخ شهر/يوم.');
      } else {
        reportPeriod = ExtractedPeriod(
          period: df ?? mf,
          status: ExtractionStatus.ambiguous,
          sourceLabel: '$reportA–$reportB',
          page: page,
          noteAr: 'تعذّر التأكد من تنسيق تاريخ فترة التقرير.',
        );
      }
    }
    if (sensorA != null && sensorB != null) {
      final sp = _period(sensorA, sensorB, dayFirst: dayFirst);
      final inside = sp != null && reportPeriod.period != null && !sp.start.isBefore(reportPeriod.period!.start) && !sp.end.isAfter(reportPeriod.period!.end);
      metricsPeriod = ExtractedPeriod(
        period: sp,
        status: (sp != null && inside) ? ExtractionStatus.found : ExtractionStatus.ambiguous,
        sourceLabel: '$sensorA–$sensorB',
        page: page,
        noteAr: 'يذكر التقرير أن بيانات الحساس متاحة فقط في هذه الفترة وأن المؤشرات محسوبة عليها.',
      );
      warnings.add('المؤشرات في هذا التقرير محسوبة على فترة توفر بيانات الحساس ($sensorA–$sensorB) وليس على كامل فترة التقرير.');
    } else {
      metricsPeriod = reportPeriod;
    }
    if (limited) warnings.add('يذكر التقرير أن بعض الأيام بياناتها محدودة أو غير موجودة.');
    warnings.add('لا يقرأ التطبيق بيانات الإنسولين أو إعدادات المضخة الموجودة في التقرير، ولا يقدّم أي توصية بشأن الجرعات.');
    warnings.add('يحتوي ملف PDF على ملخصات مطبوعة فقط؛ لم يُعِد التطبيق بناء القراءات التفصيلية.');

    return _finish(
      formatId: discoverFormatId,
      formatVerified: true,
      unit: unit,
      raw: raw,
      ambiguous: ambiguous,
      page: page,
      reportPeriod: reportPeriod,
      metricsPeriod: metricsPeriod,
      warnings: warnings,
      sensorLabel: 'نسبة اتصال الحساس (Connected Sensor Time)',
      limited: limited,
      device: device,
      reportDays: reportDays,
    );
  }

  // ---------------------------------------------------- generic (unverified)

  ExtractionResult _parseGeneric(List<List<String>> pages) {
    final raw = <MetricKey, (double, String)>{};
    final ambiguous = <MetricKey, String>{};
    var unit = GlucoseUnit.mgdl;
    int? page;
    final goal = RegExp(r'goal|target:|greater than|less than|هدف', caseSensitive: false);
    final labels = <MetricKey, RegExp>{
      MetricKey.meanGlucose: RegExp(r'(average|mean) glucose', caseSensitive: false),
      MetricKey.gmi: RegExp(r'glucose management indicator|\bGMI\b', caseSensitive: false),
      MetricKey.cv: RegExp(r'coefficient of variation|glucose variability|%\s?CV', caseSensitive: false),
      MetricKey.sensorActive: RegExp(r'time cgm (is )?active|sensor (usage|wear|active)|connected sensor time', caseSensitive: false),
    };
    final valueWithUnit = RegExp(r'(\d{1,3}(?:[.,]\d+)?)\s*(mg/dL|mmol/L)', caseSensitive: false);
    final valuePct = RegExp(r'(\d{1,3}(?:[.,]\d+)?)\s*%');

    for (var p = 0; p < pages.length; p++) {
      final lines = pages[p];
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        labels.forEach((key, re) {
          if (raw.containsKey(key) || !re.hasMatch(l)) return;
          final wantsUnit = key == MetricKey.meanGlucose;
          for (var j = i; j <= i + 2 && j < lines.length; j++) {
            final cand = j == i ? l.substring(re.firstMatch(l)!.end) : lines[j];
            if (goal.hasMatch(cand)) continue;
            final m = (wantsUnit ? valueWithUnit : valuePct).firstMatch(cand);
            if (m != null) {
              final v = _num(m.group(1)!);
              if (v == null) continue;
              if (wantsUnit) unit = parseGlucoseUnit(m.group(2)!) ?? unit;
              raw[key] = (v, l);
              page ??= p + 1;
              break;
            }
          }
        });
        if (goal.hasMatch(l)) continue;
        final lower = l.toLowerCase();
        MetricKey? band;
        if (RegExp(r'\bvery low\b').hasMatch(lower)) {
          band = MetricKey.timeVeryLow;
        } else if (RegExp(r'\bvery high\b').hasMatch(lower)) {
          band = MetricKey.timeVeryHigh;
        } else if (RegExp(r'\b(in range|target range|time in range)\b').hasMatch(lower)) {
          band = MetricKey.timeInRange;
        } else if (RegExp(r'\blow\b').hasMatch(lower)) {
          band = MetricKey.timeLow;
        } else if (RegExp(r'\bhigh\b').hasMatch(lower)) {
          band = MetricKey.timeHigh;
        }
        if (band != null) {
          final pcts = valuePct.allMatches(l).map((m) => _num(m.group(1)!)).whereType<double>().toList();
          if (pcts.length == 1) {
            if (raw.containsKey(band) && raw[band]!.$1 != pcts.single) {
              ambiguous[band] = 'ظهرت للفئة أكثر من قيمة.';
            } else {
              raw[band] = (pcts.single, l);
              page ??= p + 1;
            }
          }
        }
      }
    }

    var period = ExtractedPeriod.notFound;
    final allText = pages.expand((p) => p).join('\n');
    final iso = RegExp(r'(\d{4}-\d{2}-\d{2})\s*[–—-]+\s*(\d{4}-\d{2}-\d{2})').firstMatch(allText);
    if (iso != null) {
      final s = DateTime.tryParse(iso.group(1)!), e = DateTime.tryParse(iso.group(2)!);
      if (s != null && e != null && !e.isBefore(s)) {
        period = ExtractedPeriod(period: ReportPeriod(s, e), status: ExtractionStatus.found, sourceLabel: iso.group(0));
      }
    } else {
      final m = _slashRange.firstMatch(allText);
      if (m != null) {
        final df = _period(m.group(1)!, m.group(2)!, dayFirst: true);
        final mf = _period(m.group(1)!, m.group(2)!, dayFirst: false);
        period = ExtractedPeriod(
          period: df ?? mf,
          status: (df != null && mf != null && df != mf) || (df == null && mf == null) ? ExtractionStatus.ambiguous : ExtractionStatus.found,
          sourceLabel: m.group(0),
          noteAr: (df != null && mf != null && df != mf) ? 'تنسيق التاريخ يحتمل يوم/شهر أو شهر/يوم؛ يرجى التحقق.' : null,
        );
      }
    }
    return _finish(
      formatId: genericFormatId,
      formatVerified: false,
      unit: unit,
      raw: raw,
      ambiguous: ambiguous,
      page: page,
      reportPeriod: period,
      metricsPeriod: period,
      warnings: [
        'تنسيق التقرير غير مُتحقَّق منه. القيم استُخرجت بأفضل جهد ويجب تأكيد كل قيمة على حدة.',
        'يحتوي ملف PDF على ملخصات مطبوعة فقط؛ لم يُعِد التطبيق بناء القراءات التفصيلية.',
      ],
      sensorLabel: 'نسبة عمل الحساس',
      limited: false,
      device: null,
      reportDays: null,
    );
  }

  // ------------------------------------------------------------------ build

  ExtractionResult _finish({
    required String formatId,
    required bool formatVerified,
    required GlucoseUnit unit,
    required Map<MetricKey, (double, String)> raw,
    required Map<MetricKey, String> ambiguous,
    required int? page,
    required ExtractedPeriod reportPeriod,
    required ExtractedPeriod metricsPeriod,
    required List<String> warnings,
    required String sensorLabel,
    required bool limited,
    required String? device,
    required int? reportDays,
  }) {
    final fields = <MetricKey, ExtractedField>{};
    for (final key in MetricKey.values) {
      final unitLabel = key == MetricKey.meanGlucose || key == MetricKey.sd ? unit.label : '%';
      final r = raw[key];
      if (ambiguous.containsKey(key)) {
        fields[key] = ExtractedField(
          key: key,
          extractedValue: r?.$1,
          unit: unitLabel,
          extractionStatus: ExtractionStatus.ambiguous,
          validation: FieldValidation.notCrossChecked,
          method: ExtractionMethod.localText,
          sourcePage: page,
          sourceLabel: r?.$2,
          messagesAr: [ambiguous[key]!],
        );
        continue;
      }
      if (r == null) {
        fields[key] = ExtractedField.notFound(key, unitLabel);
        continue;
      }
      final plausible = isPlausible(key, r.$1, unit);
      fields[key] = ExtractedField(
        key: key,
        extractedValue: r.$1,
        unit: unitLabel,
        extractionStatus: ExtractionStatus.found,
        validation: !plausible
            ? FieldValidation.outOfRange
            : (formatVerified ? FieldValidation.valid : FieldValidation.notCrossChecked),
        method: ExtractionMethod.localText,
        sourcePage: page,
        sourceLabel: r.$2,
        messagesAr: plausible ? const [] : const ['القيمة خارج النطاق المعقول لهذا المؤشر.'],
      );
    }
    final result = ExtractionResult(
      formatId: formatId,
      formatVerified: formatVerified,
      glucoseUnit: unit,
      reportPeriod: reportPeriod,
      metricsPeriod: metricsPeriod,
      fields: fields,
      checks: const [],
      warningsAr: warnings,
      sensorLabel: sensorLabel,
      limitedDataNotice: limited,
      deviceLabel: device,
      reportDaysLabel: reportDays,
    );
    return applyConsistencyChecks(result);
  }
}

/// Re-runs deterministic cross-checks on the current effective values and
/// marks involved fields as inconsistent when a check fails. Used after
/// parsing, after AI reconciliation and after every user correction.
ExtractionResult applyConsistencyChecks(ExtractionResult r) {
  final values = <MetricKey, double?>{};
  r.fields.forEach((k, f) {
    final v = f.effectiveValue;
    if (v == null || f.validation == FieldValidation.outOfRange) {
      values[k] = null;
    } else if ((k == MetricKey.meanGlucose || k == MetricKey.sd) && r.glucoseUnit == GlucoseUnit.mmoll) {
      values[k] = toMgdl(v, GlucoseUnit.mmoll);
    } else {
      values[k] = v;
    }
  });
  final checks = runSummaryChecks(values);
  final failing = <MetricKey, List<String>>{};
  for (final c in checks) {
    if (c.passed == false) {
      for (final k in c.involved) {
        failing.putIfAbsent(k, () => []).add(c.messageAr);
      }
    }
  }
  final fields = <MetricKey, ExtractedField>{};
  r.fields.forEach((k, f) {
    final base = f.messagesAr.where((m) => !m.startsWith('تحقق: ')).toList();
    if (f.effectiveValue == null || f.validation == FieldValidation.outOfRange) {
      fields[k] = f.copyWith(messagesAr: base);
    } else if (failing.containsKey(k)) {
      fields[k] = f.copyWith(
        validation: FieldValidation.inconsistent,
        confirmed: false,
        messagesAr: [...base, ...failing[k]!.map((m) => 'تحقق: $m')],
      );
    } else if (f.validation == FieldValidation.inconsistent) {
      // A previous inconsistency was resolved (e.g. by a correction).
      fields[k] = f.copyWith(
        validation: r.formatVerified ? FieldValidation.valid : FieldValidation.notCrossChecked,
        messagesAr: base,
      );
    } else {
      fields[k] = f.copyWith(messagesAr: base);
    }
  });
  return r.copyWith(fields: fields, checks: checks);
}
