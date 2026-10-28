import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../common/explain.dart';

/// GMI (CGM estimate) versus laboratory HbA1c, with dates, the interval
/// between them, and neutral caveats. The two values are never presented as
/// interchangeable.
class GmiComparisonScreen extends ConsumerStatefulWidget {
  const GmiComparisonScreen({super.key});
  @override
  ConsumerState<GmiComparisonScreen> createState() => _GmiComparisonScreenState();
}

class _GmiComparisonScreenState extends ConsumerState<GmiComparisonScreen> {
  String? _labId;
  String? _reportId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final t = Theme.of(context).textTheme;
    final labs = s.labs.where((l) => l.testCode == LabTestCode.hba1c).toList()
      ..sort((a, b) => (b.collectionDate ?? b.createdAt).compareTo(a.collectionDate ?? a.createdAt));
    final reports = s.datedReports.reversed.toList();

    GmiHbA1cComparison c = ref.watch(gmiComparisonProvider);
    if (_labId != null || _reportId != null) {
      LabResult? lab;
      CgmReport? rep;
      for (final l in labs) {
        if (l.id == (_labId ?? c.hba1c?.id)) lab = l;
      }
      for (final r in reports) {
        if (r.id == (_reportId ?? c.reportId)) rep = r;
      }
      c = compareGmiWithHbA1c(report: rep, hba1c: lab);
    }

    return SpPage(
      title: 'GMI مقابل HbA1c',
      children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: c.hba1c?.id,
              decoration: const InputDecoration(labelText: 'نتيجة HbA1c'),
              items: [
                for (final l in labs)
                  DropdownMenuItem(value: l.id, child: Text('${hba1cDisplay(l).split(' (').first} — ${l.collectionDate == null ? 'بلا تاريخ' : ArFormat.shortDate(l.collectionDate!)}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _labId = v),
            ),
          ),
          const SizedBox(width: SpSpace.sm),
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: c.reportId,
              decoration: const InputDecoration(labelText: 'تقرير الحساس'),
              items: [
                for (final r in reports)
                  DropdownMenuItem(value: r.id, child: Text(ArFormat.period(r.effectivePeriod!), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _reportId = v),
            ),
          ),
        ]),
        const SizedBox(height: SpSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _ValueCard(
              title: 'HbA1c',
              kind: 'تحليل دم مخبري',
              color: SpColors.seriesLab,
              value: c.hba1cPercent == null ? 'غير متاح' : '${ArFormat.number(c.hba1cPercent!)}%',
              detail: c.hba1c == null
                  ? 'لا توجد نتيجة'
                  : '${c.hba1c!.collectionDate == null ? 'بلا تاريخ سحب' : 'سُحبت ${ArFormat.date(c.hba1c!.collectionDate!)}'}${c.hba1cWasConverted ? '\nالأصل: ${hba1cDisplay(c.hba1c!).split(' (').first}' : ''}',
            ),
          ),
          const SizedBox(width: SpSpace.sm),
          Expanded(
            child: _ValueCard(
              title: 'GMI',
              kind: c.gmiOrigin == ValueOrigin.extractedFromReport.name ? 'تقدير مطبوع في تقرير الحساس' : 'تقدير محسوب من متوسط الحساس',
              color: SpColors.seriesGmi,
              value: c.gmiPercent == null ? 'غير متاح' : '${ArFormat.number(c.gmiPercent!)}%',
              detail: c.period == null ? 'فترة غير معروفة' : 'فترة ${ArFormat.period(c.period!)}',
            ),
          ),
        ]),
        const SizedBox(height: SpSpace.lg),
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('هل يمكن مقارنتهما؟', style: t.titleSmall)),
              StatusChip(
                label: c.comparability.labelAr,
                tone: c.comparability == Comparability.aligned ? Tone.info : Tone.neutral,
                icon: c.comparability == Comparability.aligned ? Icons.link_rounded : Icons.link_off_rounded,
              ),
            ]),
            const SizedBox(height: SpSpace.sm),
            if (c.daysFromPeriodEndToLab != null)
              KeyValueRow(
                label: 'المدة بين نهاية فترة الحساس وسحب العينة',
                value: c.daysFromPeriodEndToLab! >= 0 ? ArFormat.days(c.daysFromPeriodEndToLab!) : 'قبلها بـ ${ArFormat.days(c.daysFromPeriodEndToLab!)}',
              ),
            if (c.differencePercentPoints != null)
              KeyValueRow(label: 'الفرق الرقمي (HbA1c − GMI)', value: '${ArFormat.signed(c.differencePercentPoints!)} نقطة مئوية', emphasize: true)
            else
              Text('لا يُعرض فرق رقمي لأن شروط المقارنة غير مكتملة.', style: t.bodySmall),
            const SizedBox(height: SpSpace.sm),
            for (final n in c.notesAr) Padding(padding: const EdgeInsets.only(bottom: 6), child: InfoNote(text: n)),
            const InfoNote(tone: Tone.info, text: GmiHbA1cComparison.neutralityNoteAr),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ماذا تمثل كل قيمة؟', style: t.titleSmall),
            const SizedBox(height: SpSpace.xs),
            Text(GmiHbA1cComparison.explanationHbA1cAr, style: t.bodyMedium),
            const SizedBox(height: SpSpace.xs),
            Text(GmiHbA1cComparison.explanationGmiAr, style: t.bodyMedium),
            const SizedBox(height: SpSpace.xs),
            Text('طريقة العرض: تُعد الفترتان متقاربتين إذا سُحبت العينة خلال فترة الحساس أو خلال 30 يومًا بعدها. هذه قاعدة عرض قابلة للتعديل وليست معيارًا سريريًا.',
                style: t.bodySmall),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        Wrap(spacing: SpSpace.sm, runSpacing: SpSpace.sm, children: [
          OutlinedButton.icon(onPressed: () => showExplanationSheet(context, ref, gmiContext(c)), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('اشرح لي المقارنة')),
          OutlinedButton.icon(onPressed: () => context.push('/labs/add?code=hba1c'), icon: const Icon(Icons.add_rounded), label: const Text('إضافة نتيجة HbA1c')),
        ]),
      ],
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.title, required this.kind, required this.color, required this.value, required this.detail});
  final String title;
  final String kind;
  final Color color;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(title, style: t.titleSmall),
        ]),
        Text(kind, style: t.labelSmall),
        const SizedBox(height: SpSpace.sm),
        Text(value, style: t.headlineSmall),
        const SizedBox(height: 4),
        Text(detail, style: t.bodySmall),
      ]),
    );
  }
}
