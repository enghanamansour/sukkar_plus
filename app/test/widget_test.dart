// Widget tests (require the Flutter SDK: `flutter test`). They were written
// against Flutter 3.47.8 but could NOT be executed in the sandbox where this
// project was built (no Flutter engine available there). Run them locally.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukkar_core/sukkar_core.dart';
import 'package:sukkar_plus/app.dart';
import 'package:sukkar_plus/core/config/app_config.dart';
import 'package:sukkar_plus/data/platform/pdf_text.dart';
import 'package:sukkar_plus/data/providers.dart';

/// Returns the synthetic report text without PDFium (not available in tests).
class _FakeExtractor implements PdfTextExtractor {
  _FakeExtractor(this.now);
  final DateTime now;
  @override
  Future<List<String>> extractPages(Uint8List bytes) async => [demoUploadLines(now).join('\n')];
}

void main() {
  final now = DateTime(2026, 10, 28, 9);

  Widget app() => ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(supabaseUrl: '', supabaseKey: '', forceDemo: true)),
          clockProvider.overrideWithValue(() => now),
          pdfTextExtractorProvider.overrideWithValue(_FakeExtractor(now)),
        ],
        child: const SukkarApp(),
      );

  testWidgets('demo mode shows the banner and the welcome screen, then home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('وضع العرض — بيانات تجريبية'), findsOneWidget);
    expect(find.text('استكشاف البيانات التجريبية دون موافقة'), findsOneWidget);
    await tester.tap(find.text('استكشاف البيانات التجريبية دون موافقة'));
    await tester.pumpAndSettle();
    expect(find.text('ملخصي الصحي'), findsOneWidget);
    expect(find.text('آخر مستجداتك'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
  });

  testWidgets('switching to the demo reviewer shows the review dashboard', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('استكشاف البيانات التجريبية دون موافقة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملفي'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('التبديل إلى المراجع التجريبي'), 300);
    await tester.tap(find.text('التبديل إلى المراجع التجريبي'));
    await tester.pumpAndSettle();
    expect(find.text('لوحة المراجعة'), findsOneWidget);
    expect(find.textContaining('REQ-7Q2K'), findsOneWidget);
  });
}
