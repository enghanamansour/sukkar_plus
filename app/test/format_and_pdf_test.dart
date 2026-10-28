// Pure Dart (no Flutter): Arabic formatting and the PDF builders used for the
// demo report and the visit-summary export.
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:sukkar_core/sukkar_core.dart';
import 'package:sukkar_plus/core/format/ar_format.dart';
import 'package:sukkar_plus/data/platform/pdf_builders.dart';
import 'package:test/test.dart';

pw.Font _font(String name) {
  for (final dir in ['assets/fonts', 'app/assets/fonts']) {
    final f = File('$dir/$name');
    if (f.existsSync()) return pw.Font.ttf(ByteData.sublistView(f.readAsBytesSync()));
  }
  throw StateError('font $name not found');
}

void main() {
  group('ArFormat', () {
    test('Arabic day counting forms', () {
      expect(ArFormat.days(1), 'يوم واحد');
      expect(ArFormat.days(2), 'يومان');
      expect(ArFormat.days(7), '7 أيام');
      expect(ArFormat.days(14), '14 يومًا');
    });
    test('periods use words between dates (bidi-safe)', () {
      expect(ArFormat.period(ReportPeriod(DateTime(2026, 7, 16), DateTime(2026, 7, 29))), '16 يوليو إلى 29 يوليو 2026');
      expect(ArFormat.period(ReportPeriod(DateTime(2025, 12, 20), DateTime(2026, 1, 2))), '20 ديسمبر 2025 إلى 2 يناير 2026');
    });
    test('changes and signed values', () {
      expect(ArFormat.change(172, 153), 'من 172 إلى 153 (−19)');
      expect(ArFormat.signed(0.04), '0');
      expect(ArFormat.signed(0.4), '+0.4');
    });
    test('relative days', () {
      final now = DateTime(2026, 10, 28, 9);
      expect(ArFormat.relativeDay(now, DateTime(2026, 10, 28)), 'اليوم');
      expect(ArFormat.relativeDay(now, DateTime(2026, 10, 29)), 'غدًا');
      expect(ArFormat.relativeDay(now, DateTime(2026, 11, 9)), 'بعد 12 يومًا');
    });
    test('unavailable metrics are never shown as zero', () {
      expect(ArFormat.metric(null), 'غير متاح');
      expect(
        ArFormat.metric(const MetricValue(
            key: MetricKey.cv, value: null, unit: '%', origin: ValueOrigin.extractedFromReport, status: VerificationStatus.unavailable)),
        'غير متاح',
      );
    });
  });

  group('PDF builders', () {
    final regular = _font('IBMPlexSansArabic_400Regular.ttf');
    final bold = _font('IBMPlexSansArabic_700Bold.ttf');
    final now = DateTime(2026, 10, 28, 16);

    test('synthetic demo report PDF passes upload validation', () async {
      final bytes = await buildSyntheticReportPdf(demoUploadLines(now), regular: regular);
      expect(validatePdfBytes('synthetic_demo_report.pdf', bytes).isValid, isTrue);
    });

    test('visit summary PDF builds for the demo dataset and for an empty account', () async {
      final repo = buildDemoRepository(now);
      final full = const VisitSummaryBuilder().build(
        now: now,
        reports: await repo.listReports(demoPatientActor),
        labs: await repo.listLabs(demoPatientActor),
        reminders: await repo.listReminders(demoPatientActor),
        followUps: await repo.listFollowUps(demoPatientActor),
        appointment: (await repo.listAppointments(demoPatientActor)).first,
        targetProfile: TargetProfile.generalAdultT1T2,
      );
      final empty = const VisitSummaryBuilder().build(
          now: now, reports: const [], labs: const [], reminders: const [], followUps: const [], appointment: null, targetProfile: TargetProfile.unspecified);
      for (final s in [full, empty]) {
        final bytes = await buildVisitSummaryPdf(s, regular: regular, bold: bold);
        expect(validatePdfBytes('summary.pdf', bytes).isValid, isTrue);
        expect(bytes.length, greaterThan(5000));
      }
    });
  });
}
