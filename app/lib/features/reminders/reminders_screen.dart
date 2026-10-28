import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final now = ref.read(clockProvider)();
    final t = Theme.of(context).textTheme;
    final appt = s.nextAppointment(now);
    final groups = <ReminderDisplayState, List<TestReminder>>{};
    for (final r in s.reminders) {
      groups.putIfAbsent(r.displayState(now), () => []).add(r);
    }
    const order = [ReminderDisplayState.overdue, ReminderDisplayState.upcoming, ReminderDisplayState.completed, ReminderDisplayState.cancelled];

    return Scaffold(
      appBar: AppBar(title: const Text('التحاليل الدورية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReminderEditor(context, ref),
        icon: const Icon(Icons.add_alarm_outlined),
        label: const Text('تذكير جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, 96),
        children: [
          const InfoNote(
            text: 'سجّل هنا التحاليل التي طلبها فريقك الصحي أو أكدها لك. التطبيق لا يحدد جدولًا للتحاليل ولا يفترض أن تحليلًا ما مطلوب لمجرد الإصابة بالسكري.',
          ),
          const SizedBox(height: SpSpace.md),
          if (appt != null)
            SpCard(
              child: Row(children: [
                const Icon(Icons.event_outlined, color: SpColors.tealDeep),
                const SizedBox(width: SpSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('الموعد القادم ${ArFormat.relativeDay(now, appt.dateTime)}', style: t.titleSmall),
                    Text('${appt.clinicLabel} — ${ArFormat.dateTime(appt.dateTime)}', style: t.bodySmall),
                  ]),
                ),
              ]),
            ),
          if (appt != null) ...[
            const SizedBox(height: SpSpace.sm),
            Text(preAppointmentSuggestionAr, style: t.bodySmall),
          ],
          const SizedBox(height: SpSpace.md),
          if (s.reminders.isEmpty)
            EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'لا توجد تذكيرات',
              message: 'أضف تذكيرًا بتحليل طلبه فريقك الصحي، واربطه بموعدك إن وُجد.',
              actionLabel: 'تذكير جديد',
              onAction: () => showReminderEditor(context, ref),
            ),
          for (final st in order)
            if (groups[st]?.isNotEmpty ?? false) ...[
              const SizedBox(height: SpSpace.md),
              Text('${st.labelAr} (${groups[st]!.length})', style: t.titleSmall),
              const SizedBox(height: SpSpace.sm),
              for (final r in groups[st]!) Padding(padding: const EdgeInsets.only(bottom: SpSpace.sm), child: _ReminderCard(reminder: r, appointment: appt)),
            ],
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder, required this.appointment});
  final TestReminder reminder;
  final Appointment? appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final t = Theme.of(context).textTheme;
    final r = reminder;
    final ctrl = ref.read(appControllerProvider.notifier);
    final state = r.displayState(now);
    final beforeAppt = appointment != null && r.isOpen && daysBetween(r.dueDate, appointment!.dateTime) >= 0;
    final (tone, icon) = switch (state) {
      ReminderDisplayState.overdue => (Tone.critical, Icons.error_outline),
      ReminderDisplayState.upcoming => (Tone.info, Icons.schedule_rounded),
      ReminderDisplayState.completed => (Tone.neutral, Icons.check_circle_outline),
      ReminderDisplayState.cancelled => (Tone.neutral, Icons.block_rounded),
    };

    Future<void> act(Future<void> Function() f, String done) async {
      try {
        await f();
        if (context.mounted) showSnack(context, done);
      } on UserFacingError catch (e) {
        if (context.mounted) showSnack(context, e.messageAr);
      }
    }

    return SpCard(
      padding: const EdgeInsets.all(SpSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.testName, style: t.titleSmall)),
          StatusChip(label: state.labelAr, tone: tone, icon: icon),
        ]),
        const SizedBox(height: 2),
        Text('الاستحقاق: ${ArFormat.date(r.dueDate)} (${ArFormat.relativeDay(now, r.dueDate)})', style: t.bodySmall),
        if (r.remindAt != null && r.isOpen) Text('التذكير: ${ArFormat.dateTime(r.remindAt!)}', style: t.bodySmall),
        if (r.status == ReminderStatus.completed && r.collectionDate != null) Text('سُحبت العينة: ${ArFormat.date(r.collectionDate!)}', style: t.bodySmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          StatusChip(label: r.source.labelAr, tone: Tone.neutral, icon: Icons.medical_information_outlined),
          if (beforeAppt) const StatusChip(label: 'قبل موعدك القادم', tone: Tone.warning, icon: Icons.event_available_outlined),
          SyntheticChip(show: r.provenance == DataProvenance.synthetic),
        ]),
        if (r.note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.note!, style: t.labelSmall)),
        if (r.isOpen) ...[
          const SizedBox(height: SpSpace.xs),
          Wrap(spacing: 2, children: [
            TextButton.icon(
              onPressed: () => context.push('/labs/add?reminder=${r.id}'),
              icon: const Icon(Icons.add_chart_outlined, size: 18),
              label: const Text('تم — أدخل النتيجة'),
            ),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: now, initialDate: now, helpText: 'تاريخ سحب العينة');
                if (d != null) await act(() => ctrl.completeReminder(r, collectionDate: d), 'سُجّل التحليل كمكتمل.');
              },
              child: const Text('تم دون نتيجة'),
            ),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: now, lastDate: DateTime(now.year + 2), initialDate: r.dueDate.isBefore(now) ? now : r.dueDate, helpText: 'تاريخ الاستحقاق الجديد');
                if (d != null) await act(() => ctrl.rescheduleReminder(r, d), 'أُعيدت الجدولة.');
              },
              child: const Text('إعادة جدولة'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'إلغاء التذكير؟', message: r.testName, confirmLabel: 'إلغاء التذكير', destructive: true);
                if (ok) await act(() => ctrl.cancelReminder(r), 'أُلغي التذكير.');
              },
              child: const Text('إلغاء'),
            ),
          ]),
        ],
        if (r.history.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text('السجل', style: t.labelMedium),
              children: [
                for (final h in r.history)
                  Align(alignment: AlignmentDirectional.centerStart, child: Text('${ArFormat.date(h.at)} — ${h.descriptionAr}', style: t.labelSmall)),
              ],
            ),
          ),
      ]),
    );
  }
}

Future<void> showReminderEditor(BuildContext context, WidgetRef ref) async {
  final now = ref.read(clockProvider)();
  final appt = ref.read(appControllerProvider).nextAppointment(now);
  var code = LabTestCode.hba1c;
  final name = TextEditingController();
  final note = TextEditingController();
  DateTime due = now.add(const Duration(days: 7));
  TimeOfDay remindTime = const TimeOfDay(hour: 9, minute: 0);
  var remindDaysBefore = 1;
  var source = ScheduleSource.clinicianProvided;
  var linkAppt = appt != null;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(SpSpace.xl, 0, SpSpace.xl, SpSpace.xl),
            children: [
              Text('تذكير بتحليل', style: t.titleLarge),
              const SizedBox(height: SpSpace.md),
              DropdownButtonFormField<LabTestCode>(
                initialValue: code,
                decoration: const InputDecoration(labelText: 'التحليل'),
                items: [for (final c in LabTestCode.values) DropdownMenuItem(value: c, child: Text(c.labelAr))],
                onChanged: (c) => set(() => code = c ?? code),
              ),
              if (code == LabTestCode.other) ...[
                const SizedBox(height: SpSpace.sm),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم التحليل')),
              ],
              const SizedBox(height: SpSpace.sm),
              DropdownButtonFormField<ScheduleSource>(
                initialValue: source,
                decoration: const InputDecoration(labelText: 'مصدر الجدول'),
                items: [for (final s in ScheduleSource.values) DropdownMenuItem(value: s, child: Text(s.labelAr))],
                onChanged: (s) => set(() => source = s ?? source),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('تاريخ الاستحقاق'),
                subtitle: Text(ArFormat.date(due)),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, firstDate: now, lastDate: DateTime(now.year + 2), initialDate: due);
                  if (d != null) set(() => due = d);
                },
              ),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: remindDaysBefore,
                    decoration: const InputDecoration(labelText: 'التذكير قبل'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('في اليوم نفسه')),
                      DropdownMenuItem(value: 1, child: Text('بيوم')),
                      DropdownMenuItem(value: 3, child: Text('بثلاثة أيام')),
                      DropdownMenuItem(value: 7, child: Text('بأسبوع')),
                    ],
                    onChanged: (v) => set(() => remindDaysBefore = v ?? 1),
                  ),
                ),
                const SizedBox(width: SpSpace.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final tm = await showTimePicker(context: ctx, initialTime: remindTime);
                      if (tm != null) set(() => remindTime = tm);
                    },
                    child: Text('الساعة ${remindTime.format(ctx)}'),
                  ),
                ),
              ]),
              if (appt != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: linkAppt,
                  onChanged: (v) => set(() => linkAppt = v ?? false),
                  title: Text('ربط بالموعد القادم (${ArFormat.date(appt.dateTime)})'),
                ),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
              const SizedBox(height: SpSpace.sm),
              Text('التذكير داخل التطبيق. إشعارات النظام غير مفعّلة في هذا النموذج الأولي.', style: t.bodySmall),
              const SizedBox(height: SpSpace.md),
              FilledButton(
                onPressed: () async {
                  final remindDay = due.subtract(Duration(days: remindDaysBefore));
                  try {
                    await ref.read(appControllerProvider.notifier).createReminder(
                          code: code,
                          testName: name.text,
                          dueDate: due,
                          source: source,
                          remindAt: DateTime(remindDay.year, remindDay.month, remindDay.day, remindTime.hour, remindTime.minute),
                          appointmentId: linkAppt ? appt?.id : null,
                          note: note.text.trim().isEmpty ? null : note.text.trim(),
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } on UserFacingError catch (e) {
                    if (ctx.mounted) showSnack(ctx, e.messageAr);
                  }
                },
                child: const Text('حفظ التذكير'),
              ),
            ],
          ),
        );
      },
    ),
  );
  name.dispose();
  note.dispose();
}
