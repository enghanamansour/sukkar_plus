import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/charts/trend_chart.dart';
import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final t = Theme.of(context).textTheme;
    final trend = hba1cTrend(s.labs);
    final cmp = ref.watch(gmiComparisonProvider);
    final others = s.labs.where((l) => l.testCode != LabTestCode.hba1c).toList()
      ..sort((a, b) => (b.collectionDate ?? b.createdAt).compareTo(a.collectionDate ?? a.createdAt));
    final hba = s.labs.where((l) => l.testCode == LabTestCode.hba1c).toList()
      ..sort((a, b) => (b.collectionDate ?? b.createdAt).compareTo(a.collectionDate ?? a.createdAt));
    final gmiPoints = [
      for (final r in s.datedReports)
        if (r.metrics[MetricKey.gmi]?.isVerified ?? false) ChartPoint(r.effectivePeriod!.end, r.metrics[MetricKey.gmi]!.value!, note: 'نهاية فترة الحساس'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحاليل'),
        actions: [IconButton(onPressed: () => context.push('/reminders'), icon: const Icon(Icons.event_repeat_outlined), tooltip: 'التحاليل الدورية')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/labs/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة نتيجة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, 96),
        children: [
          SectionHeader(title: 'السكر التراكمي (HbA1c) عبر الزمن', actionLabel: 'مقارنة مع GMI', onAction: () => context.push('/labs/gmi')),
          SpCard(
            child: trend.points.isEmpty && gmiPoints.isEmpty
                ? EmptyState(
                    icon: Icons.bloodtype_outlined,
                    title: 'لا توجد نتائج HbA1c مؤرخة',
                    message: 'أضف نتيجة المختبر مع تاريخ سحب العينة لعرض الاتجاه.',
                    actionLabel: 'إضافة HbA1c',
                    onAction: () => context.push('/labs/add?code=hba1c'),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TrendChart(
                      unit: '%',
                      series: [
                        if (trend.points.isNotEmpty)
                          ChartSeries(
                            name: 'HbA1c (مختبر)',
                            color: SpColors.seriesLab,
                            points: [for (final p in trend.points) ChartPoint(p.date, p.value, note: p.converted ? 'محوّل من mmol/mol' : null)],
                          ),
                        if (gmiPoints.isNotEmpty)
                          ChartSeries(name: 'GMI (تقدير من الحساس)', color: SpColors.seriesGmi, points: gmiPoints, shape: PointShape.diamond, dashed: true),
                      ],
                    ),
                    if (trend.change != null) ...[
                      const Divider(height: SpSpace.xl),
                      KeyValueRow(
                        label: 'آخر تغيّر في HbA1c',
                        value: '${trend.change!.direction.labelAr} ${ArFormat.signed(trend.change!.delta)} نقطة',
                        emphasize: true,
                      ),
                      Text(
                        'من ${ArFormat.number(trend.change!.previous.value)}% (${ArFormat.date(trend.change!.previous.date)}) إلى ${ArFormat.number(trend.change!.current.value)}% (${ArFormat.date(trend.change!.current.date)}) خلال ${ArFormat.days(trend.change!.daysBetween)}.',
                        style: t.bodySmall,
                      ),
                    ],
                    for (final m in trend.missingAr) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $m', style: t.bodySmall)),
                    if (trend.change != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(causationNoteAr, style: t.labelSmall)),
                  ]),
          ),
          const SizedBox(height: SpSpace.md),
          SpCard(
            onTap: () => context.push('/labs/gmi'),
            child: Row(children: [
              const Icon(Icons.compare_arrows_rounded, color: SpColors.tealDeep),
              const SizedBox(width: SpSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GMI مقابل آخر HbA1c', style: t.titleSmall),
                  Text(cmp.comparability.labelAr, style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: SpColors.inkMuted),
            ]),
          ),
          const SizedBox(height: SpSpace.xl),
          const SectionHeader(title: 'نتائج HbA1c'),
          if (hba.isEmpty) Text('لا توجد نتائج.', style: t.bodyMedium),
          for (final l in hba) _LabTile(lab: l),
          const SizedBox(height: SpSpace.xl),
          const SectionHeader(title: 'تحاليل أخرى', subtitle: 'تُعرض كما أدخلتها مع مرجع المختبر إن وُجد. لا يفسّر التطبيق هذه النتائج.'),
          if (others.isEmpty) Text('لا توجد تحاليل أخرى مسجلة.', style: t.bodyMedium),
          for (final l in others) _LabTile(lab: l, trend: labTrend(s.labs, code: l.testCode, testName: l.testName)),
        ],
      ),
    );
  }
}

class _LabTile extends ConsumerWidget {
  const _LabTile({required this.lab, this.trend});
  final LabResult lab;
  final TrendSeries? trend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final value = lab.testCode == LabTestCode.hba1c ? hba1cDisplay(lab) : '${ArFormat.number(lab.value, decimals: 2)} ${lab.unit}';
    final change = trend?.change;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpSpace.sm),
      child: SpCard(
        padding: const EdgeInsets.all(SpSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(lab.testName, style: t.titleSmall)),
            Text(value, style: t.titleSmall),
          ]),
          const SizedBox(height: 2),
          Text(
            [
              lab.collectionDate == null ? 'بلا تاريخ سحب' : 'سحب العينة: ${ArFormat.date(lab.collectionDate!)}',
              if (lab.labName != null) lab.labName!,
            ].join(' — '),
            style: t.bodySmall,
          ),
          if (lab.referenceInterval != null && !lab.referenceInterval!.isEmpty)
            Text('مرجع المختبر: ${lab.referenceInterval!.describe(lab.unit)}', style: t.labelSmall),
          if (change != null && lab.id == change.current.sourceId)
            Text('السابق ${ArFormat.number(change.previous.value, decimals: 2)} (${ArFormat.date(change.previous.date)}) — ${change.direction.labelAr} ${ArFormat.signed(change.delta, decimals: 2)}',
                style: t.labelSmall),
          const SizedBox(height: 6),
          Row(children: [
            StatusChip(label: lab.source.labelAr, tone: Tone.neutral, icon: Icons.keyboard_outlined),
            const SizedBox(width: 6),
            StatusChip(label: lab.verification.labelAr, tone: lab.isVerified ? Tone.info : Tone.warning),
            const SizedBox(width: 6),
            SyntheticChip(show: lab.provenance == DataProvenance.synthetic),
            const Spacer(),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: SpColors.inkMuted),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'حذف النتيجة؟', message: lab.testName, confirmLabel: 'حذف', destructive: true);
                if (ok) await ref.read(appControllerProvider.notifier).deleteLab(lab.id);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
