import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/demo_banner.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final demo = ref.watch(appControllerProvider.select((s) => s.demoMode));
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: SpSpace.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: SpColors.tealSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: SpColors.tealDeep, size: 22),
            ),
            const SizedBox(width: SpSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall),
                Text(body, style: t.bodySmall),
              ]),
            ),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpSpace.xl),
          children: [
            const SizedBox(height: SpSpace.lg),
            const Align(alignment: AlignmentDirectional.centerStart, child: SukkarLogo(size: 52, withWordmark: true)),
            const SizedBox(height: SpSpace.xl),
            Text('رفيقك لفهم تقارير السكر والاستعداد لموعدك', style: t.headlineSmall),
            const SizedBox(height: SpSpace.sm),
            Text('يجمع تقارير الحساس ونتائج المختبر في ملخص واحد مؤرخ، ويوضح ما يمكن مقارنته وما ينقص.', style: t.bodyMedium),
            const SizedBox(height: SpSpace.xl),
            point(Icons.description_outlined, 'يقرأ تقريرك المطبوع', 'يستخرج المؤشرات من ملف PDF ويطلب منك تأكيدها قبل استخدامها.'),
            point(Icons.compare_arrows_rounded, 'يقارن بتواريخ واضحة', 'GMI مع HbA1c، والفترات السابقة مع الحالية، مع بيان حدود كل مقارنة.'),
            point(Icons.event_available_outlined, 'يجهزك للموعد', 'تذكيرات بالتحاليل التي طلبها فريقك، وأسئلة مقترحة، وملخص قابل للتصدير.'),
            point(Icons.support_agent_outlined, 'طلب مراجعة بشرية (محاكاة)', 'عندما تنطبق قاعدة مُعدّة أو تطلب ذلك بنفسك. لا يُرسل شيء لجهة صحية حقيقية.'),
            const InfoNote(
              tone: Tone.warning,
              title: 'ليس بديلًا عن الرعاية الطبية',
              text: 'لا يشخّص التطبيق، ولا يحدد الحالات الطارئة، ولا يقترح جرعات أو تغييرًا في العلاج.',
            ),
            const SizedBox(height: SpSpace.xl),
            FilledButton(onPressed: () => context.push('/consent'), child: const Text('متابعة إلى الموافقة')),
            if (demo) ...[
              const SizedBox(height: SpSpace.sm),
              OutlinedButton(
                onPressed: () {
                  ref.read(appControllerProvider.notifier).completeOnboarding();
                  context.go('/');
                },
                child: const Text('استكشاف البيانات التجريبية دون موافقة'),
              ),
              const SizedBox(height: SpSpace.xs),
              Text('تستطيع استكشاف البيانات التجريبية الآن. ستُطلب الموافقة قبل معالجة أي تقرير حقيقي.',
                  style: t.bodySmall, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
