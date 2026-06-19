import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/features/reminders/data/reminder_repository.dart';
import 'package:smart_med/features/reminders/data/reminder_sync_service.dart';

void main() {
  group('MedicationReminderSyncService', () {
    late FakeFirebaseFirestore firestore;
    late ReminderRepository repository;
    late MedicationReminderSyncService service;

    const uid = 'user-123';
    const medicationId = 'med-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ReminderRepository(firestore: firestore);
      service = MedicationReminderSyncService(repository: repository);
    });

    test('writes one reminder document per medication schedule slot', () async {
      final medication = _buildMedication(
        id: medicationId,
        userId: uid,
        name: 'Ibuprofen',
        notificationIds: const <int>[101, 202],
      );

      await service.replaceMedicationReminders(
        uid: uid,
        medicationId: medicationId,
        medication: medication,
        now: DateTime(2026, 6, 1, 7, 30),
        timezone: 'Asia/Jerusalem',
      );

      final reminders = await repository.listReminders(
        uid: uid,
        medicationId: medicationId,
      );
      final morning = reminders.firstWhere((item) => item.slotIndex == 0);
      final evening = reminders.firstWhere((item) => item.slotIndex == 1);

      expect(reminders, hasLength(2));
      expect(reminders.map((item) => item.id).toSet(), {
        'med-123-slot-0',
        'med-123-slot-1',
      });
      expect(morning.userId, uid);
      expect(morning.medicationName, 'Ibuprofen');
      expect(morning.hour, 8);
      expect(morning.minute, 0);
      expect(morning.repeatDays, MedicationReminderSyncService.dailyRepeatDays);
      expect(morning.timezone, 'Asia/Jerusalem');
      expect(morning.startDate, DateTime(2026, 6, 1));
      expect(morning.nextTriggerAt, DateTime(2026, 6, 1, 8));
      expect(morning.notificationId, 101);
      expect(morning.isEnabled, isTrue);
      expect(evening.notificationId, 202);

      final morningSnapshot = await FirestorePaths.reminderDoc(
        firestore,
        uid,
        'med-123-slot-0',
      ).get();

      expect(morningSnapshot.data()!['lastTriggeredAt'], isNull);
      expect(morningSnapshot.data()!['createdAt'], isNotNull);
      expect(morningSnapshot.data()!['updatedAt'], isNotNull);
    });

    test('replaces old reminders for only the target medication', () async {
      await FirestorePaths.remindersCollection(
        firestore,
        uid,
      ).doc('med-123-slot-0').set({
        'userId': uid,
        'medicationId': medicationId,
        'medicationName': 'Old Name',
        'slotIndex': 0,
        'hour': 6,
        'minute': 0,
        'repeatDays': MedicationReminderSyncService.dailyRepeatDays,
        'timezone': 'UTC',
        'isEnabled': true,
      });
      await FirestorePaths.remindersCollection(
        firestore,
        uid,
      ).doc('other-slot-0').set({
        'userId': uid,
        'medicationId': 'other',
        'medicationName': 'Other',
        'slotIndex': 0,
        'hour': 12,
        'minute': 0,
        'repeatDays': MedicationReminderSyncService.dailyRepeatDays,
        'timezone': 'UTC',
        'isEnabled': true,
      });

      await service.replaceMedicationReminders(
        uid: uid,
        medicationId: medicationId,
        medication: _buildMedication(id: medicationId, userId: uid),
        now: DateTime(2026, 6, 1, 7, 30),
      );

      final targetReminders = await repository.listReminders(
        uid: uid,
        medicationId: medicationId,
      );
      final otherReminders = await repository.listReminders(
        uid: uid,
        medicationId: 'other',
      );

      expect(targetReminders.map((item) => item.hour).toSet(), {8, 20});
      expect(otherReminders, hasLength(1));
    });

    test('leaves notificationId empty when ids are not one-to-one', () {
      final reminders = service.buildReminderRecords(
        uid: uid,
        medicationId: medicationId,
        medication: _buildMedication(
          id: medicationId,
          userId: uid,
          notificationIds: const <int>[101, 202, 303],
        ),
        now: DateTime(2026, 6, 1, 7, 30),
      );

      expect(reminders, hasLength(2));
      expect(reminders.every((item) => item.notificationId == null), isTrue);
    });
  });
}

MedicationRecord _buildMedication({
  String? id,
  required String userId,
  String name = 'Sample Medication',
  List<MedicationScheduleTime> scheduledTimes = const [
    MedicationScheduleTime(hour: 8, minute: 0),
    MedicationScheduleTime(hour: 20, minute: 0),
  ],
  List<int> notificationIds = const <int>[],
}) {
  return MedicationRecord(
    id: id,
    userId: userId,
    name: name,
    doseAmount: 200,
    doseUnit: 'mg',
    frequencyPerDay: scheduledTimes.length,
    scheduledTimes: scheduledTimes,
    startDate: DateTime(2026, 6, 1),
    remindersEnabled: true,
    status: 'active',
    notificationIds: notificationIds,
  );
}
