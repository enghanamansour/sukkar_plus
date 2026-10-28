import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/charts/range_bands.dart';
import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class CgmHistoryScreen extends ConsumerWidget {
  const CgmHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final t = Theme.of(context).textTheme;
    final cmp = compareLatestCgmPeriods(s.reports);
    final dated = s.datedReports.reversed.toList();

    return SpPage(
      title: 'مقارنة فترات الحساس',
      children: [
        if (cmp == null)
          SpCard(
            child: EmptyState(
              icon: Icons.timeline_rounded,
              title: 'نحتاج تقريرين على الأقل',
              message: 'المقارنة تتطلب تقريرين موثّقين بفترات معروفة. ارفع تقريرًا آخر لفترة مختلفة.',
              actionLabel: 'رفع تقرير',
              onAction: () => context.push('/upload'),
            ),
          )
        else ...[
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _PeriodStrip(label: 'السابقة', report: cmp.previous),
              const SizedBox(height: SpSpace.md),
              _PeriodStrip(label: 'الحالية', report: cmp.current),
              const SizedBox(height: SpSpace.sm),
              Wrap(spacing: 10, runSpacing: 4, children: [
                for (final b in bandSpecs)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Text(b.label, style: t.labelSmall),
                  ]),
              ]),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'التغيّر في المؤشرات الموثّقة', subtitle: 'تُقارن فقط القيم الموثّقة في التقريرين معًا.'),
          SpCard(
            child: cmp.changes.isEmpty
                ? Text('لا توجد مؤشرات موثّقة مشتركة يمكن مقارنتها.', style: t.bodyMedium)
                : Column(children: [
                    Row(children: [
                      Expanded(flex: 4, child: Text('المؤشر', style: t.labelMedium)),
                      Expanded(flex: 2, child: Text('السابقة', style: t.labelMedium, textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('الحالية', style: t.labelMedium, textAlign: TextAlign.center)),
                      Expanded(flex: 3, child: Text('التغيّر', style: t.labelMedium, textAlign: TextAlign.end)),
                    ]),
                    const Divider(height: SpSpace.lg),
                    for (final e in cmp.changes.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(flex: 4, child: Text(e.key.labelAr, style: t.bodySmall?.copyWith(color: SpColors.ink))),
                          Expanded(flex: 2, child: Text(ArFormat.number(e.value.previous.value), textAlign: TextAlign.center, style: t.bodyMedium)),
                          Expanded(flex: 2, child: Text(ArFormat.number(e.value.current.value), textAlign: TextAlign.center, style: t.titleSmall)),
                          Expanded(
                            flex: 3,
                            child: Text('${e.value.direction.labelAr} ${ArFormat.signed(e.value.delta)}',
                                textAlign: TextAlign.end, style: t.bodySmall?.copyWith(color: SpColors.ink)),
                          ),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: SpSpace.md),
          for (final n in cmp.notesAr) Padding(padding: const EdgeInsets.only(bottom: SpSpace.sm), child: InfoNote(text: n)),
        ],
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'كل التقارير'),
        if (dated.isEmpty) Text('لا توجد تقارير.', style: t.bodyMedium),
        for (final r in dated)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.sm),
            child: SpCard(
              onTap: () => context.push('/report/${r.id}'),
              padding: const EdgeInsets.all(SpSpace.md),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ArFormat.period(r.effectivePeriod!), style: t.titleSmall),
                    Text('${r.sourceType.labelAr} — الوقت ضمن النطاق ${ArFormat.metric(r.metrics[MetricKey.timeInRange])}', style: t.bodySmall),
                  ]),
                ),
                SyntheticChip(show: r.provenance == DataProvenance.synthetic),
              ]),
            ),
          ),
      ],
    );
  }
}

class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({required this.label, required this.report});
  final String label;
  final CgmReport report;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('الفترة $label', style: t.titleSmall),
        const SizedBox(width: SpSpace.sm),
        Expanded(child: Text(ArFormat.period(report.effectivePeriod!), style: t.bodySmall)),
        Text('TIR ${ArFormat.metric(report.metrics[MetricKey.timeInRange])}', style: t.labelMedium),
      ]),
      const SizedBox(height: 6),
      RangeStrip(report: report),
    ]);
  }
}
