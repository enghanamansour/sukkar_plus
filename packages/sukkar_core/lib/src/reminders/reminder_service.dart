import '../common/units.dart';
import '../models/care.dart';
import '../models/enums.dart';
import '../models/lab.dart';

class InvalidTransitionException implements Exception {
  InvalidTransitionException(this.messageAr);
  final String messageAr;
  @override
  String toString() => 'InvalidTransitionException: $messageAr';
}

/// Pure state transitions for laboratory reminders.
///
/// Reminders always come from a clinician-provided or user-confirmed schedule;
/// this service never creates reminders on its own.
class ReminderService {
  const ReminderService();

  TestReminder create({
    required String id,
    required String userId,
    required LabTestCode testCode,
    required String testName,
    required DateTime dueDate,
    required ScheduleSource source,
    required DateTime now,
    DateTime? remindAt,
    String? appointmentId,
    String? note,
    DataProvenance provenance = DataProvenance.real,
  }) {
    if (testCode == LabTestCode.other && testName.trim().isEmpty) {
      throw InvalidTransitionException('أدخل اسم التحليل.');
    }
    if (remindAt != null && remindAt.isAfter(DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59))) {
      throw InvalidTransitionException('وقت التذكير يجب أن يكون قبل تاريخ الاستحقاق أو في يومه.');
    }
    return TestReminder(
      id: id,
      userId: userId,
      testCode: testCode,
      testName: testName.trim().isEmpty ? testCode.labelAr : testName.trim(),
      dueDate: dateOnly(dueDate),
      source: source,
      status: ReminderStatus.scheduled,
      provenance: provenance,
      remindAt: remindAt,
      appointmentId: appointmentId,
      note: note,
      history: [ReminderEvent(now, 'أُنشئ التذكير (${source.labelAr})')],
    );
  }

  TestReminder complete(TestReminder r, {required DateTime now, DateTime? collectionDate, String? resultId}) {
    if (r.status != ReminderStatus.scheduled) {
      throw InvalidTransitionException('لا يمكن إكمال تذكير ${r.status == ReminderStatus.completed ? 'مكتمل' : 'ملغى'}.');
    }
    if (collectionDate != null && daysBetween(now, collectionDate) > 0) {
      throw InvalidTransitionException('تاريخ سحب العينة لا يمكن أن يكون في المستقبل.');
    }
    return r.copyWith(
      status: ReminderStatus.completed,
      completedAt: now,
      collectionDate: collectionDate,
      resultId: resultId,
      history: [...r.history, ReminderEvent(now, 'تم إكمال التحليل')],
    );
  }

  TestReminder reschedule(TestReminder r, {required DateTime newDueDate, required DateTime now, DateTime? newRemindAt}) {
    if (r.status != ReminderStatus.scheduled) {
      throw InvalidTransitionException('لا يمكن إعادة جدولة تذكير غير نشط.');
    }
    if (newRemindAt != null && newRemindAt.isAfter(DateTime(newDueDate.year, newDueDate.month, newDueDate.day, 23, 59))) {
      throw InvalidTransitionException('وقت التذكير يجب أن يكون قبل تاريخ الاستحقاق أو في يومه.');
    }
    return r.copyWith(
      dueDate: dateOnly(newDueDate),
      remindAt: newRemindAt,
      history: [...r.history, ReminderEvent(now, 'أُعيدت الجدولة إلى ${arDate(newDueDate)}')],
    );
  }

  TestReminder cancel(TestReminder r, {required DateTime now, String? reasonAr}) {
    if (r.status != ReminderStatus.scheduled) {
      throw InvalidTransitionException('التذكير ليس نشطًا.');
    }
    return r.copyWith(
      status: ReminderStatus.cancelled,
      history: [...r.history, ReminderEvent(now, 'أُلغي التذكير${reasonAr == null ? '' : ': $reasonAr'}')],
    );
  }

  /// Open reminders that are due on or before the appointment date.
  List<TestReminder> dueBeforeAppointment(Iterable<TestReminder> reminders, Appointment appt) => reminders
      .where((r) => r.isOpen && daysBetween(r.dueDate, appt.dateTime) >= 0)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// Reminders whose reminder time has passed and that are still open.
  /// Used for in-app reminder banners (local/push notifications are optional).
  List<TestReminder> dueNow(Iterable<TestReminder> reminders, DateTime now) =>
      reminders.where((r) => r.isOpen && (r.remindAt != null ? !r.remindAt!.isAfter(now) : daysBetween(now, r.dueDate) <= 0)).toList();
}

/// General educational prompt shown before an appointment. It deliberately
/// names no specific test and states that the care team decides.
const preAppointmentSuggestionAr =
    'اقتراح عام للتأكد: اسأل فريقك الصحي عن التحاليل المطلوبة قبل موعدك القادم، إن وُجدت. التطبيق لا يحدد جدول التحاليل.';
