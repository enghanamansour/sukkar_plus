import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import 'followup_widgets.dart';

class FollowUpsScreen extends ConsumerWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final t = Theme.of(context).textTheme;
    return SpPage(
      title: 'طلبات المراجعة',
      children: [
        const InfoNote(tone: Tone.demo, text: notSentToProvidersAr),
        const SizedBox(height: SpSpace.md),
        if (s.followUps.isEmpty)
          const EmptyState(
            icon: Icons.support_agent_outlined,
            title: 'لا توجد طلبات',
            message: 'يمكنك طلب مراجعة بشرية من صفحة تحليل أي تقرير.',
          ),
        for (final f in s.followUps)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.sm),
            child: SpCard(
              onTap: () => context.push('/followup/${f.id}'),
              padding: const EdgeInsets.all(SpSpace.md),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.pseudoId, style: t.titleSmall),
                    Text('${ArFormat.date(f.createdAt)} — آخر تحديث ${ArFormat.relativeDay(DateTime.now(), f.updatedAt)}', style: t.bodySmall),
                    if (f.decision != null) Text('القرار: ${f.decision!.labelAr}', style: t.labelSmall),
                  ]),
                ),
                FollowUpStatusChip(status: f.status),
              ]),
            ),
          ),
      ],
    );
  }
}
