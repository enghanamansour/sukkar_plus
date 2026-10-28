import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/platform/pdf_documents.dart';
import '../../data/providers.dart';

class VisitPrepScreen extends ConsumerStatefulWidget {
  const VisitPrepScreen({super.key});
  @override
  ConsumerState<VisitPrepScreen> createState() => _VisitPrepScreenState();
}

class _VisitPrepScreenState extends ConsumerState<VisitPrepScreen> {
  bool _exporting = false;

  Future<void> _export(VisitSummary s) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildVisitSummaryPdf(s);
      await shareVisitSummaryPdf(bytes);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر إنشاء ملف PDF على هذا الجهاز.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(visitSummaryProvider);
    final now = ref.read(clockProvider)();
    final t = Theme.of(context).textTheme;
    final appt = s.appointment;
    final r = s.latestReport;
    final gmi = s.gmiComparison;

    Widget bulletList(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 5, color: SpColors.inkSecondary)),
                  const SizedBox(width: SpSpace.sm),
                  Expanded(child: Text(i, style: t.bodyMedium)),
                ]),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('استعد لموعدك')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.xxl),
        children: [
          SpCard(
            color: SpColors.tealSoft,
            border: false,
            child: Row(children: [
              const Icon(Icons.event_available_outlined, color: SpColors.tealDeep, size: 30),
              const SizedBox(width: SpSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(appt == null ? 'لا يوجد موعد قادم مسجل' : 'موعدك ${ArFormat.relativeDay(now, appt.dateTime)}', style: t.titleMedium),
                  Text(appt == null ? 'يمكنك تجهيز الملخص في أي وقت.' : '${appt.clinicLabel}\n${ArFormat.weekdayDate(appt.dateTime)} — ${ArFormat.time(appt.dateTime)}',
                      style: t.bodySmall),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          SectionHeader(title: 'قبل الموعد', actionLabel: 'التحاليل الدورية', onAction: () => context.push('/reminders')),
          SpCard(
            child: s.dueBeforeAppointment.isEmpty
                ? Text(appt == null ? 'لا يوجد موعد لربط التحاليل به.' : 'لا توجد تحاليل مسجلة مستحقة قبل الموعد. $preAppointmentSuggestionAr', style: t.bodyMedium)
                : Column(children: [
                    for (final rem in s.dueBeforeAppointment)
                      KeyValueRow(
                        label: rem.testName,
                        value: '${rem.displayState(now).labelAr} — ${ArFormat.shortDate(rem.dueDate)}',
                        trailing: TextButton(onPressed: () => context.push('/labs/add?reminder=${rem.id}'), child: const Text('أدخل النتيجة')),
                      ),
                  ]),
          ),
          const SizedBox(height: SpSpace.lg),
          SectionHeader(title: 'أحدث بيانات الحساس', actionLabel: r == null ? null : 'التفاصيل', onAction: r == null ? null : () => context.push('/report/${r.id}')),
          SpCard(
            child: r == null
                ? Text('لا يوجد تقرير موثّق.', style: t.bodyMedium)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.effectivePeriod == null ? 'فترة غير معروفة' : ArFormat.period(r.effectivePeriod!), style: t.titleSmall),
                    const SizedBox(height: SpSpace.xs),
                    for (final l in s.latestMetrics) KeyValueRow(label: l.labelAr, value: l.valueAr),
                    if (s.qualityWarningsAr.isNotEmpty) ...[const SizedBox(height: SpSpace.sm), for (final w in s.qualityWarningsAr) InfoNote(tone: Tone.warning, text: w)],
                  ]),
          ),
          const SizedBox(height: SpSpace.lg),
          SectionHeader(title: 'المقارنات', actionLabel: 'الفترات', onAction: () => context.push('/history')),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.cgmComparison == null)
                Text('لا يوجد تقريران للمقارنة التاريخية.', style: t.bodyMedium)
              else ...[
                Text('من ${ArFormat.period(s.cgmComparison!.previous.effectivePeriod!)}\nإلى ${ArFormat.period(s.cgmComparison!.current.effectivePeriod!)}', style: t.titleSmall),
                for (final e in s.cgmComparison!.changes.entries.where((e) => const {
                      MetricKey.timeInRange,
                      MetricKey.timeBelowRangeTotal,
                      MetricKey.timeAboveRangeTotal,
                      MetricKey.gmi,
                    }.contains(e.key)))
                  KeyValueRow(label: e.key.labelAr, value: ArFormat.change(e.value.previous.value, e.value.current.value)),
              ],
              const Divider(height: SpSpace.xl),
              KeyValueRow(label: 'GMI مقابل HbA1c', value: gmi.comparability.labelAr),
              if (gmi.differencePercentPoints != null) KeyValueRow(label: 'الفرق (HbA1c − GMI)', value: '${ArFormat.signed(gmi.differencePercentPoints!)} نقطة'),
              if (s.hba1cTrend.change != null)
                KeyValueRow(label: 'آخر تغيّر في HbA1c', value: '${s.hba1cTrend.change!.direction.labelAr} ${ArFormat.signed(s.hba1cTrend.change!.delta)}'),
            ]),
          ),
          const SizedBox(height: SpSpace.lg),
          if (s.missingAr.isNotEmpty) ...[
            const SectionHeader(title: 'بيانات ناقصة'),
            SpCard(child: bulletList(s.missingAr)),
            const SizedBox(height: SpSpace.lg),
          ],
          if (s.followUpLines.isNotEmpty) ...[
            SectionHeader(title: 'طلبات المراجعة (محاكاة)', actionLabel: 'عرض', onAction: () => context.push('/followups')),
            SpCard(child: Column(children: [for (final l in s.followUpLines) KeyValueRow(label: l.labelAr, value: l.valueAr)])),
            const SizedBox(height: SpSpace.lg),
          ],
          const SectionHeader(title: 'أسئلة قد ترغب في طرحها', subtitle: 'أمثلة محايدة مبنية على البيانات المتاحة، وليست نصيحة طبية.'),
          SpCard(child: bulletList(s.questionsAr)),
          const SizedBox(height: SpSpace.lg),
          const InfoNote(tone: Tone.warning, text: VisitSummary.disclaimerAr),
          const SizedBox(height: SpSpace.lg),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export(s),
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('تصدير الملخص PDF'),
          ),
        ],
      ),
    );
  }
}
