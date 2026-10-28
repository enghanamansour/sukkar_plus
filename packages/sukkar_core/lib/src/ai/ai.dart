import '../common/units.dart';
import '../rules/rules.dart';

/// A verified value the language model is allowed to mention.
class GroundedValue {
  const GroundedValue({required this.labelAr, required this.value, required this.unit});
  final String labelAr;
  final double value;
  final String unit;

  String get formatted => '${formatNumber(value)}${unit == '%' ? '%' : ' $unit'}';
  Map<String, Object?> toJson() => {'label': labelAr, 'value': roundTo(value, 1), 'unit': unit};
}

enum ExplanationTopic { reportSummary, gmiVsHbA1c, missingData }

/// Everything the explainer may use. Only verified values are included;
/// missing values are listed as missing, never estimated.
class ExplanationContext {
  const ExplanationContext({
    required this.topic,
    required this.values,
    this.periodLabel,
    this.periodDays,
    this.missingAr = const [],
    this.outcome,
    this.extraAllowedNumbers = const {},
    this.dateNumbers = const {},
  });

  final ExplanationTopic topic;
  final List<GroundedValue> values;
  final String? periodLabel;
  final int? periodDays;
  final List<String> missingAr;
  final ReviewOutcome? outcome;
  final Set<double> extraAllowedNumbers;

  /// Components of dates that may appear (years, months, days).
  final Set<int> dateNumbers;

  /// Numbers the generated text may contain: grounded values (rounded to
  /// 0, 1 and 2 decimals), general reference target numbers, period length,
  /// date parts and small counting numbers.
  Set<double> allowedNumbers() => {
        for (final v in values) ...[v.value, roundTo(v.value, 0), roundTo(v.value, 1), roundTo(v.value, 2)],
        ...extraAllowedNumbers,
        if (periodDays != null) periodDays!.toDouble(),
        for (final d in dateNumbers) d.toDouble(),
        // General reference numbers that appear in source-backed text.
        14, 70, 180, 54, 250, 4, 1, 25, 5, 36, 2,
      };

  Map<String, Object?> toJson() => {
        'topic': topic.name,
        'period': periodLabel,
        'period_days': periodDays,
        'verified_values': [for (final v in values) v.toJson()],
        'missing': missingAr,
        'outcome': outcome?.wireName,
      };
}

enum ExplanationSource { ai, localTemplate }

class Explanation {
  const Explanation({required this.text, required this.source, this.fallbackReasonAr});
  final String text;
  final ExplanationSource source;

  /// Why AI text was not used (unavailable, not configured, failed validation).
  final String? fallbackReasonAr;

  String get sourceLabelAr => source == ExplanationSource.ai ? 'نص مولّد بالذكاء الاصطناعي ومُتحقَّق منه' : 'نص من قالب محلي (دون ذكاء اصطناعي)';
}

/// Abstraction over the language-model provider so the app and tests run
/// without credentials. Implementations: [LocalTemplateExplainer] (always
/// available) and the app's backend-backed provider.
abstract class ExplanationProvider {
  String get name;
  bool get isLive;
  Future<Explanation> explain(ExplanationContext ctx);
}

class AiTextValidation {
  const AiTextValidation(this.ok, this.reasons);
  final bool ok;
  final List<String> reasons;
}

/// Safety and grounding checks applied to every model-generated text.
class AiTextValidator {
  const AiTextValidator({this.maxLength = 1500});
  final int maxLength;

  static final _banned = <RegExp>[
    // Dosing / treatment changes.
    RegExp('جرع'), RegExp('وحد(ة|ات) (من )?(ال)?[إا]نسولين'), RegExp('زد (من )?'), RegExp('ارفع جرعة'), RegExp('قلل'), RegExp('قلّل'),
    RegExp('أوقف'), RegExp('توقف عن'), RegExp('غيّ?ر (ال)?دواء'), RegExp('عدّ?ل (ال)?علاج'),
    RegExp(r'\bdos(e|es|ing|age)\b', caseSensitive: false),
    RegExp(r'units? of insulin', caseSensitive: false),
    RegExp(r'\b(increase|decrease|reduce|adjust) your\b', caseSensitive: false),
    RegExp(r'\bstop taking\b', caseSensitive: false),
    // Diagnosis / alarming judgement.
    RegExp('تشخيص'), RegExp('مصاب ب'), RegExp('لديك مرض'), RegExp('خطير'), RegExp('غير طبيعي'), RegExp('حالة طارئة'),
    RegExp(r'diagnos', caseSensitive: false), RegExp(r'\bdangerous\b', caseSensitive: false), RegExp(r'\babnormal\b', caseSensitive: false),
  ];

  static String normalizeDigits(String s) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = arabicIndic.indexOf(ch);
      final j = persian.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (j >= 0) {
        b.write(j);
      } else if (ch == '٫') {
        b.write('.');
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  AiTextValidation validate(String text, Set<double> allowedNumbers) {
    final reasons = <String>[];
    final t = text.trim();
    if (t.isEmpty) reasons.add('النص فارغ.');
    if (t.length > maxLength) reasons.add('النص أطول من المسموح.');
    for (final re in _banned) {
      if (re.hasMatch(t)) {
        reasons.add('يحتوي النص على صياغة غير مسموحة (${re.pattern}).');
      }
    }
    final normalized = normalizeDigits(t);
    for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(normalized)) {
      final n = double.parse(m.group(0)!);
      final grounded = allowedNumbers.any((a) => (a - n).abs() <= 0.051);
      if (!grounded) reasons.add('رقم غير مستند إلى البيانات الموثّقة: ${m.group(0)}');
    }
    return AiTextValidation(reasons.isEmpty, reasons);
  }
}

/// Deterministic Arabic explanations; used when AI is unavailable or its
/// output fails validation.
class LocalTemplateExplainer implements ExplanationProvider {
  const LocalTemplateExplainer();

  @override
  String get name => 'local-template';

  @override
  bool get isLive => false;

  @override
  Future<Explanation> explain(ExplanationContext ctx) async => Explanation(text: build(ctx), source: ExplanationSource.localTemplate);

  String build(ExplanationContext ctx) {
    final b = StringBuffer();
    switch (ctx.topic) {
      case ExplanationTopic.reportSummary:
        b.write(ctx.periodLabel != null ? 'هذا ملخص تقرير الحساس للفترة ${ctx.periodLabel}' : 'هذا ملخص تقرير الحساس');
        b.writeln(ctx.periodDays != null ? ' (${ctx.periodDays} يومًا).' : '.');
        if (ctx.values.isEmpty) {
          b.writeln('لا توجد قيم موثّقة لعرضها بعد.');
        } else {
          b.writeln('القيم الموثّقة:');
          for (final v in ctx.values) {
            b.writeln('• ${v.labelAr}: ${v.formatted}');
          }
        }
        if (ctx.outcome != null) {
          b.writeln();
          b.writeln('نتيجة القواعد المُعدّة: ${ctx.outcome!.titleAr}. ${ctx.outcome!.explanationAr}');
        }
      case ExplanationTopic.gmiVsHbA1c:
        b.writeln('GMI تقدير يُحسب من متوسط قراءات الحساس خلال فترة التقرير، بينما HbA1c تحليل دم مخبري.');
        for (final v in ctx.values) {
          b.writeln('• ${v.labelAr}: ${v.formatted}');
        }
        b.writeln('اختلاف القيمتين أمر شائع ولا يعني وحده تشخيصًا أو سببًا محددًا. يمكنك مناقشته مع فريقك الصحي.');
      case ExplanationTopic.missingData:
        b.writeln(ctx.missingAr.isEmpty ? 'لا توجد بيانات ناقصة واضحة في السجلات الحالية.' : 'البيانات الناقصة أو غير الكافية:');
        for (final m in ctx.missingAr) {
          b.writeln('• $m');
        }
    }
    if (ctx.missingAr.isNotEmpty && ctx.topic != ExplanationTopic.missingData) {
      b.writeln();
      b.writeln('ملاحظات حول البيانات:');
      for (final m in ctx.missingAr) {
        b.writeln('• $m');
      }
    }
    b.write('هذا شرح تعليمي ولا يغني عن استشارة فريقك الصحي.');
    return b.toString().trim();
  }
}

/// Wraps a live provider: validates its text and falls back to the template.
class GuardedExplainer implements ExplanationProvider {
  const GuardedExplainer(this.inner, {this.validator = const AiTextValidator(), this.fallback = const LocalTemplateExplainer()});
  final ExplanationProvider inner;
  final AiTextValidator validator;
  final LocalTemplateExplainer fallback;

  @override
  String get name => 'guarded(${inner.name})';

  @override
  bool get isLive => inner.isLive;

  @override
  Future<Explanation> explain(ExplanationContext ctx) async {
    Explanation raw;
    try {
      raw = await inner.explain(ctx);
    } catch (e) {
      return Explanation(text: fallback.build(ctx), source: ExplanationSource.localTemplate, fallbackReasonAr: 'تعذّر الوصول إلى خدمة الذكاء الاصطناعي.');
    }
    if (raw.source != ExplanationSource.ai) return raw;
    final v = validator.validate(raw.text, ctx.allowedNumbers());
    if (!v.ok) {
      return Explanation(
        text: fallback.build(ctx),
        source: ExplanationSource.localTemplate,
        fallbackReasonAr: 'رُفض نص الذكاء الاصطناعي لعدم اجتيازه فحوص السلامة والاستناد إلى البيانات.',
      );
    }
    return raw;
  }
}
