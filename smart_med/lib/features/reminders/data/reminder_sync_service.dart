import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/features/reminders/data/models/reminder_record.dart';
import 'package:smart_med/features/reminders/data/reminder_repository.dart';
import 'package:timezone/timezone.dart' as tz;

class MedicationReminderSyncService {
  MedicationReminderSyncService({ReminderRepository? repository})
    : _repository = repository ?? reminderRepository;

  static const List<int> dailyRepeatDays = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  final ReminderRepository _repository;

  Future<void> replaceMedicationReminders({
    required String uid,
    required String medicationId,
    required MedicationRecord medication,
    DateTime? now,
    String? timezone,
  }) {
    final reminders = buildReminderRecords(
      uid: uid,
      medicationId: medicationId,
      medication: medication,
      now: now,
      timezone: timezone,
    );

    return _repository.replaceMedicationReminders(
      uid: uid,
      medicationId: medicationId,
      reminders: reminders,
    );
  }

  Future<void> deleteMedicationReminders({
    required String uid,
    required String medicationId,
  }) {
    return _repository.deleteMedicationReminders(
      uid: uid,
      medicationId: medicationId,
    );
  }

  List<ReminderRecord> buildReminderRecords({
    required String uid,
    required String medicationId,
    required MedicationRecord medication,
    DateTime? now,
    String? timezone,
  }) {
    final scheduledTimes = medication.scheduledTimes;
    final oneToOneNotificationIds =
        medication.notificationIds.length == scheduledTimes.length
        ? medication.notificationIds
        : const <int>[];
    final currentTime = now ?? DateTime.now();
    final effectiveTimezone = _normalizeTimezone(
      timezone ?? _localTimezoneName(),
    );
    final isEnabled =
        medication.remindersEnabled && _isActiveStatus(medication.status);

    return List<ReminderRecord>.generate(scheduledTimes.length, (slotIndex) {
      final scheduledTime = scheduledTimes[slotIndex];
      final notificationId = oneToOneNotificationIds.isEmpty
          ? null
          : oneToOneNotificationIds[slotIndex];

      return ReminderRecord(
        id: reminderIdForSlot(medicationId: medicationId, slotIndex: slotIndex),
        userId: uid,
        medicationId: medicationId,
        medicationName: medication.name,
        slotIndex: slotIndex,
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
        repeatDays: dailyRepeatDays,
        timezone: effectiveTimezone,
        startDate: medication.startDate,
        nextTriggerAt: _nextTriggerAt(
          scheduledTime,
          startDate: medication.startDate,
          endDate: medication.endDate,
          now: currentTime,
        ),
        lastTriggeredAt: null,
        notificationId: notificationId,
        isEnabled: isEnabled,
      );
    }, growable: false);
  }

  static String reminderIdForSlot({
    required String medicationId,
    required int slotIndex,
  }) {
    return '$medicationId-slot-$slotIndex';
  }

  static bool _isActiveStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'active';
  }

  static String _normalizeTimezone(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'UTC' : normalized;
  }

  static String _localTimezoneName() {
    try {
      return tz.local.name;
    } catch (_) {
      return 'UTC';
    }
  }

  static DateTime? _nextTriggerAt(
    MedicationScheduleTime time, {
    required DateTime? startDate,
    required DateTime? endDate,
    required DateTime now,
  }) {
    final DateTime candidateFromStart = _dateWithTime(startDate ?? now, time);
    DateTime candidate;

    if (!candidateFromStart.isBefore(now)) {
      candidate = candidateFromStart;
    } else {
      candidate = _dateWithTime(now, time);
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
    }

    final endOfLastDate = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    if (endOfLastDate != null && candidate.isAfter(endOfLastDate)) {
      return null;
    }

    return candidate;
  }

  static DateTime _dateWithTime(DateTime date, MedicationScheduleTime time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

final MedicationReminderSyncService medicationReminderSyncService =
    MedicationReminderSyncService();
