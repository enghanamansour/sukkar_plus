import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/demo_banner.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final ctrl = ref.read(appControllerProvider.notifier);
    final t = Theme.of(context).textTheme;
    final ai = ref.watch(aiExtractionProvider);
    final explainer = ref.watch(explanationProvider);
    final dispatcher = ref.watch(dispatcherProvider);
    final p = s.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.xxl),
        children: [
          SpCard(
            child: Row(children: [
              const SukkarLogo(size: 44),
              const SizedBox(width: SpSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.displayName.isNotEmpty == true ? p!.displayName : 'مستخدم', style: t.titleMedium),
                  Text('المعرّف المستعار: ${p?.pseudoId ?? '—'}', style: t.bodySmall),
                ]),
              ),
              if (s.demoMode) const SyntheticChip(),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'الفئة المرجعية للأهداف', subtitle: 'اختر ما أكده لك فريقك الصحي. لا يستنتج التطبيق فئتك.'),
          SpCard(
            child: Column(children: [
              DropdownButtonFormField<TargetProfile>(
                initialValue: s.targetProfile,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: [for (final tp in TargetProfile.values) DropdownMenuItem(value: tp, child: Text(tp.labelAr, overflow: TextOverflow.ellipsis))],
                onChanged: (v) {
                  if (v != null) ctrl.setTargetProfile(v);
                },
              ),
              const SizedBox(height: SpSpace.sm),
              for (final n in consensusTargetsFor(s.targetProfile).notesAr) Padding(padding: const EdgeInsets.only(top: 4), child: InfoNote(text: n)),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'الموافقة والخصوصية'),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KeyValueRow(label: 'الموافقة', value: s.consent == null ? 'غير ممنوحة' : 'سارية منذ ${ArFormat.date(s.consent!.grantedAt)}'),
              KeyValueRow(label: 'إرسال التقارير للذكاء الاصطناعي', value: (s.consent?.allowsExternalAi ?? false) ? 'مسموح' : 'غير مسموح'),
              const SizedBox(height: SpSpace.sm),
              Wrap(spacing: SpSpace.sm, runSpacing: SpSpace.sm, children: [
                OutlinedButton(onPressed: () => context.push('/consent'), child: Text(s.consent == null ? 'منح الموافقة' : 'مراجعة الموافقة')),
                if (s.consent != null)
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: 'سحب الموافقة؟', message: 'لن تتمكن من رفع تقارير حقيقية حتى تمنحها مجددًا.', confirmLabel: 'سحب الموافقة');
                      if (ok) await ctrl.revokeConsent();
                    },
                    child: const Text('سحب الموافقة'),
                  ),
              ]),
              const SizedBox(height: SpSpace.sm),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: SpColors.critical),
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'حذف جميع بياناتي؟',
                      message: 'سيُحذف كل ما حفظته: التقارير المؤكدة، نتائج المختبر، التذكيرات، طلبات المراجعة والموافقة. لا يمكن التراجع.',
                      confirmLabel: 'حذف كل البيانات',
                      destructive: true);
                  if (ok) {
                    await ctrl.deleteAllMyData();
                    if (context.mounted) showSnack(context, 'حُذفت بياناتك.');
                  }
                },
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('حذف جميع بياناتي'),
              ),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'حالة الخدمات', subtitle: 'ما يعمل فعليًا في هذا التشغيل.'),
          SpCard(
            child: Column(children: [
              KeyValueRow(label: 'التخزين', value: s.demoMode ? 'ذاكرة الجهاز (تجريبي، يُمسح عند الإغلاق)' : 'Supabase مع سياسات RLS'),
              const KeyValueRow(label: 'قراءة ملفات PDF', value: 'على الجهاز (PDFium)'),
              KeyValueRow(label: 'استخراج بالذكاء الاصطناعي', value: ai.label),
              KeyValueRow(label: 'الشرح', value: explainer.isLive ? 'Gemini عبر الخادم + فحص + قالب احتياطي' : 'قالب محلي دون ذكاء اصطناعي'),
              KeyValueRow(label: 'إشعارات الطلبات', value: dispatcher.label),
              const KeyValueRow(label: 'إشعارات النظام', value: 'غير مفعّلة (تنبيهات داخل التطبيق فقط)'),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          if (s.demoMode) ...[
            const SectionHeader(title: 'أدوات العرض التجريبي'),
            SpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('بدّل إلى دور المراجع التجريبي لمراجعة الطلبات، ثم عُد لرؤية الحالة المحدثة. هذا التبديل غير متاح خارج وضع العرض.', style: t.bodySmall),
                const SizedBox(height: SpSpace.sm),
                FilledButton.icon(
                  onPressed: () => ctrl.switchDemoRole(UserRole.reviewer),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('التبديل إلى المراجع التجريبي'),
                ),
                const SizedBox(height: SpSpace.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: 'إعادة ضبط بيانات العرض؟', message: 'ستعود البيانات التجريبية إلى حالتها الأولى.', confirmLabel: 'إعادة الضبط');
                    if (ok) await ctrl.resetDemo();
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('إعادة ضبط بيانات العرض'),
                ),
              ]),
            ),
          ] else
            OutlinedButton.icon(onPressed: ctrl.signOut, icon: const Icon(Icons.logout_rounded), label: const Text('تسجيل الخروج')),
          const SizedBox(height: SpSpace.xl),
          Text(
            'سكر بلس — نموذج أولي مستقل لمسابقة ابتكار. غير مرتبط بتطبيق صحتي أو وزارة الصحة أو أي جهة. '
            'لا يشخّص ولا يقدم توصيات علاجية. المصادر والقيود في مجلد docs.',
            style: t.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
