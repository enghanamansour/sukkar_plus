import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';
import 'followup_widgets.dart';

class FollowUpDetailScreen extends ConsumerWidget {
  const FollowUpDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final r = s.followUpById(requestId);
    final t = Theme.of(context).textTheme;
    if (r == null) {
      return const SpPage(title: 'طلب المراجعة', children: [EmptyState(icon: Icons.search_off_rounded, title: 'الطلب غير موجود', message: '')]);
    }
    final ctrl = ref.read(appControllerProvider.notifier);

    Future<void> run(Future<void> Function() f, String done) async {
      try {
        await f();
        if (context.mounted) showSnack(context, done);
      } on UserFacingError catch (e) {
        if (context.mounted) showSnack(context, e.messageAr);
      }
    }

    return SpPage(
      title: 'طلب المراجعة',
      actions: [IconButton(onPressed: () => ctrl.reload(), icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث الحالة')],
      children: [
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.pseudoId, style: t.headlineSmall?.copyWith(letterSpacing: 0.5))),
              FollowUpStatusChip(status: r.status),
            ]),
            Text('أُنشئ ${ArFormat.dateTime(r.createdAt)} — ${r.trigger.labelAr}', style: t.bodySmall),
            if (r.decision != null) ...[
              const SizedBox(height: SpSpace.md),
              InfoNote(tone: Tone.info, title: 'قرار المراجع التجريبي: ${r.decision!.labelAr}', text: r.decision!.patientMessageAr),
            ],
            if (r.status == FollowUpStatus.awaitingReview || r.status == FollowUpStatus.underReview) ...[
              const SizedBox(height: SpSpace.md),
              Text('سيظهر هنا أي تحديث من المراجع التجريبي. في وضع العرض، بدّل الدور من صفحة ملفي لمراجعة الطلب.', style: t.bodySmall),
            ],
          ]),
        ),
        const SizedBox(height: SpSpace.md),
        const InfoNote(tone: Tone.demo, text: notSentToProvidersAr),
        if (r.notes.isNotEmpty) ...[
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'ملاحظات المراجع'),
          for (final n in r.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: SpSpace.sm),
              child: SpCard(
                padding: const EdgeInsets.all(SpSpace.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.textAr, style: t.bodyMedium),
                  const SizedBox(height: 4),
                  Text('${n.authorLabel} — ${ArFormat.dateTime(n.at)}', style: t.labelSmall),
                ]),
              ),
            ),
        ],
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'سجل الحالة'),
        SpCard(child: HistoryTimeline(history: r.history)),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'سبب الطلب'),
        SpCard(child: Text(r.reasonAr, style: t.bodyMedium)),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'المعلومات المشاركة'),
        SpCard(child: SnapshotView(snapshot: r.snapshot)),
        const SizedBox(height: SpSpace.lg),
        SpCard(child: DispatchView(dispatch: r.dispatch, onRetry: () => run(() => ctrl.retryDispatch(r), 'أُعيدت محاولة الإشعار.'))),
        const SizedBox(height: SpSpace.lg),
        if (r.status == FollowUpStatus.moreInfoRequested)
          FilledButton.icon(
            onPressed: () async {
              final c = TextEditingController();
              final note = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('إعادة إرسال الطلب'),
                  content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'ما الذي أضفته؟ مثال: رفعت تقريرًا أحدث')),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('إعادة الإرسال')),
                  ],
                ),
              );
              c.dispose();
              if (note != null) await run(() => ctrl.resubmitFollowUp(r, note.isEmpty ? 'أُعيد الإرسال' : note), 'أُعيد إرسال الطلب.');
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('استكملت البيانات — إعادة الإرسال'),
          ),
        if (r.status == FollowUpStatus.draft || r.status == FollowUpStatus.awaitingReview)
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'سحب الطلب؟', message: 'سيُغلق الطلب ولن يظهر للمراجع.', confirmLabel: 'سحب الطلب', destructive: true);
              if (ok) await run(() => ctrl.withdrawFollowUp(r), 'سُحب الطلب.');
            },
            icon: const Icon(Icons.undo_rounded),
            label: const Text('سحب الطلب'),
          ),
        if (r.status == FollowUpStatus.reviewed)
          OutlinedButton.icon(onPressed: () => run(() => ctrl.closeFollowUp(r), 'أُغلق الطلب.'), icon: const Icon(Icons.lock_outline_rounded), label: const Text('إغلاق الطلب')),
      ],
    );
  }
}
