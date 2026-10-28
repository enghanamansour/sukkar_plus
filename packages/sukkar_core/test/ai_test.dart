import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

class _FakeLive implements ExplanationProvider {
  _FakeLive(this.text, {this.fail = false});
  final String text;
  final bool fail;
  @override
  String get name => 'fake';
  @override
  bool get isLive => true;
  @override
  Future<Explanation> explain(ExplanationContext ctx) async {
    if (fail) throw StateError('GEMINI_API_KEY is not configured');
    return Explanation(text: text, source: ExplanationSource.ai);
  }
}

void main() {
  const ctx = ExplanationContext(
    topic: ExplanationTopic.reportSummary,
    values: [
      GroundedValue(labelAr: 'الوقت ضمن النطاق', value: 65.5, unit: '%'),
      GroundedValue(labelAr: 'GMI', value: 7.3, unit: '%'),
    ],
    periodLabel: '2026-10-13 — 2026-10-26',
    periodDays: 14,
    dateNumbers: {2026, 10, 13, 26},
    missingAr: ['تغطية الحساس غير مذكورة.'],
  );
  const validator = AiTextValidator();

  group('AI text validation', () {
    test('grounded neutral text passes', () {
      final v = validator.validate('خلال 14 يومًا كان الوقت ضمن النطاق 65.5% وقيمة GMI 7.3%.', ctx.allowedNumbers());
      expect(v.ok, isTrue, reason: v.reasons.join(' | '));
    });
    test('Arabic-Indic digits are normalised before grounding', () {
      expect(validator.validate('الوقت ضمن النطاق ٦٥٫٥%', ctx.allowedNumbers()).ok, isTrue);
      expect(validator.validate('الوقت ضمن النطاق ٧٧%', ctx.allowedNumbers()).ok, isFalse);
    });
    test('ungrounded numbers are rejected', () {
      final v = validator.validate('متوسط السكر 190 mg/dL.', ctx.allowedNumbers());
      expect(v.ok, isFalse);
      expect(v.reasons.single, contains('190'));
    });
    test('dosing and treatment advice is rejected (Arabic and English)', () {
      for (final s in ['ننصح بزيادة جرعة الإنسولين.', 'خذ 2 وحدات إنسولين قبل الوجبة', 'أوقف الدواء', 'You should increase your basal dose.']) {
        expect(validator.validate(s, ctx.allowedNumbers()).ok, isFalse, reason: s);
      }
    });
    test('diagnostic or alarming language is rejected', () {
      for (final s in ['هذا تشخيص لحالتك', 'النتيجة خطير جدا', 'This looks abnormal']) {
        expect(validator.validate(s, ctx.allowedNumbers()).ok, isFalse, reason: s);
      }
    });
    test('empty and overlong text is rejected', () {
      expect(validator.validate('  ', ctx.allowedNumbers()).ok, isFalse);
      expect(validator.validate('أ' * 2000, ctx.allowedNumbers()).ok, isFalse);
    });
  });

  group('fallback behaviour', () {
    test('template explainer uses only supplied values and lists missing data', () async {
      final e = await const LocalTemplateExplainer().explain(ctx);
      expect(e.source, ExplanationSource.localTemplate);
      expect(e.text, contains('65.5%'));
      expect(e.text, contains('تغطية الحساس غير مذكورة.'));
      expect(e.text, isNot(contains('mg/dL')));
    });
    test('valid AI text is used', () async {
      final e = await GuardedExplainer(_FakeLive('الوقت ضمن النطاق 65.5%.')).explain(ctx);
      expect(e.source, ExplanationSource.ai);
    });
    test('invalid AI output falls back to the template', () async {
      final e = await GuardedExplainer(_FakeLive('زد جرعة الإنسولين 4 وحدات')).explain(ctx);
      expect(e.source, ExplanationSource.localTemplate);
      expect(e.fallbackReasonAr, isNotNull);
    });
    test('missing credentials / unavailable provider falls back to the template', () async {
      final e = await GuardedExplainer(_FakeLive('', fail: true)).explain(ctx);
      expect(e.source, ExplanationSource.localTemplate);
      expect(e.fallbackReasonAr, contains('تعذّر'));
    });
    test('the template never pretends to be AI', () {
      expect(const LocalTemplateExplainer().isLive, isFalse);
      expect(const Explanation(text: 'x', source: ExplanationSource.localTemplate).sourceLabelAr, contains('دون ذكاء اصطناعي'));
    });
  });
}
