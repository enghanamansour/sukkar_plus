import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

/// In-app notifications. In demo mode they simulate push notifications and
/// say so; remote push is not configured in this prototype.
class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final t = Theme.of(context).textTheme;
    return SpPage(
      title: 'آخر مستجداتك',
      children: [
        const InfoNote(text: 'التنبيهات هنا داخل التطبيق فقط. الإشعارات الخارجية (Push) غير مفعّلة في هذا النموذج الأولي.'),
        const SizedBox(height: SpSpace.md),
        if (s.notices.isEmpty) const EmptyState(icon: Icons.notifications_none_rounded, title: 'لا توجد تنبيهات', message: 'ستظهر هنا التذكيرات وتحديثات الطلبات.'),
        for (final n in s.notices)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.sm),
            child: SpCard(
              onTap: n.route == null ? null : () => context.push(n.route!),
              padding: const EdgeInsets.all(SpSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notifications_active_outlined, color: SpColors.tealDeep),
                const SizedBox(width: SpSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.textAr, style: t.bodyMedium),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(ArFormat.dateTime(n.at), style: t.labelSmall),
                      if (n.simulated) ...[const SizedBox(width: 6), const StatusChip(label: 'إشعار محاكى', tone: Tone.demo)],
                    ]),
                  ]),
                ),
                IconButton(
                  onPressed: () => ref.read(appControllerProvider.notifier).dismissNotice(n.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'إخفاء',
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
