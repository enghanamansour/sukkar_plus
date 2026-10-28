import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

/// Informed consent before processing a real report. Explains what is
/// processed, where, what the AI does and does not do, and retention.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _understood = false;
  bool _externalAi = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final aiAvailable = ref.watch(aiExtractionProvider).isAvailable;
    final t = Theme.of(context).textTheme;

    Widget section(String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: SpSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall),
            const SizedBox(height: SpSpace.xs),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 9), child: Icon(Icons.circle, size: 5, color: SpColors.inkMuted)),
                  const SizedBox(width: SpSpace.sm),
                  Expanded(child: Text(l, style: t.bodyMedium)),
                ]),
              ),
          ]),
        );

    return SpPage(
      title: 'الموافقة على معالجة البيانات',
      children: [
        if (s.consent != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.lg),
            child: InfoNote(
              tone: Tone.info,
              title: 'موافقتك سارية',
              text: 'منحت الموافقة بتاريخ ${ArFormat.date(s.consent!.grantedAt)} (الإصدار ${s.consent!.version}). يمكنك سحبها في أي وقت من صفحة ملفي.',
            ),
          ),
        section('ما البيانات التي نعالجها؟', [
          'ملف PDF لتقرير الحساس الذي تختاره، ونتائج المختبر التي تدخلها بنفسك، والتذكيرات التي تنشئها.',
          'لا يقرأ التطبيق اسمك أو تاريخ ميلادك أو الرقم التسلسلي للجهاز من التقرير، ولا يقرأ بيانات الإنسولين أو إعدادات المضخة.',
        ]),
        section('أين تتم المعالجة؟', [
          'يُقرأ نص الملف على جهازك. لا يُخزَّن ملف PDF نفسه، وتُحفظ القيم التي تؤكدها فقط.',
          s.demoMode
              ? 'في وضع العرض تبقى كل البيانات على هذا الجهاز ولا تُرسل إلى أي خادم.'
              : 'تُحفظ القيم المؤكدة في قاعدة بيانات محمية بحيث لا يصل إليها غيرك.',
        ]),
        section('ماذا يفعل الذكاء الاصطناعي وما لا يفعله؟', [
          'يساعد اختياريًا في قراءة التقرير وصياغة شرح عربي يعتمد فقط على القيم الموثّقة.',
          'لا يحسب المؤشرات (تُحسب بشيفرة ثابتة)، ولا يشخّص، ولا يقترح جرعات أو أدوية، ولا يحدد الحالات الطارئة.',
          'كل قيمة يقترحها تُتحقق آليًا ثم تعرض عليك للتأكيد.',
        ]),
        section('طلبات المراجعة', [
          'طلبات المراجعة في هذا النموذج الأولي محاكاة، ولا تُرسل إلى أي طبيب أو جهة صحية حقيقية.',
          'عند الإرسال يُشارك فقط ملخص القيم الذي تراجعه بنفسك، مع معرّف مستعار.',
        ]),
        section('الاحتفاظ والحذف', [
          'يمكنك حذف جميع بياناتك وسحب الموافقة في أي وقت من صفحة ملفي.',
        ]),
        const InfoNote(
          tone: Tone.warning,
          text: 'هذا نموذج أولي للعرض وليس بديلًا عن الرعاية الطبية، ولا يدّعي الامتثال لأي معيار تنظيمي.',
        ),
        const SizedBox(height: SpSpace.lg),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _understood,
          onChanged: (v) => setState(() => _understood = v ?? false),
          title: Text('قرأت ما سبق وأوافق على معالجة التقرير الذي أختاره على جهازي.', style: t.bodyMedium),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _externalAi && aiAvailable && !s.demoMode,
          onChanged: (aiAvailable && !s.demoMode) ? (v) => setState(() => _externalAi = v ?? false) : null,
          title: Text('أوافق اختياريًا على إرسال ملف التقرير إلى خدمة Gemini عبر الخادم للمساعدة في الاستخراج.', style: t.bodyMedium),
          subtitle: Text(
            (aiAvailable && !s.demoMode)
                ? 'يُرسل الملف لمرة واحدة ولا يُحفظ لدينا. راجع شروط مزوّد الخدمة.'
                : 'غير متاح: خدمة الذكاء الاصطناعي غير مفعّلة في هذا التشغيل.',
            style: t.bodySmall,
          ),
        ),
      ],
      bottom: FilledButton(
        onPressed: !_understood
            ? null
            : () async {
                final wasOnboarded = s.onboardingDone;
                await ref.read(appControllerProvider.notifier).grantConsent(allowExternalAi: _externalAi);
                if (!context.mounted) return;
                showSnack(context, 'سُجّلت موافقتك (${ConsentRecord.currentVersion}).');
                if (wasOnboarded && context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
        child: const Text('أوافق ومتابعة'),
      ),
    );
  }
}
