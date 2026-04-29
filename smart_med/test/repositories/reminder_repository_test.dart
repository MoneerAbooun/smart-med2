import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/reminders/data/models/reminder_record.dart';
import 'package:smart_med/features/reminders/data/reminder_repository.dart';

void main() {
  group('ReminderRepository', () {
    late FakeFirebaseFirestore firestore;
    late ReminderRepository repository;

    const uid = 'user-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ReminderRepository(firestore: firestore);
    });

    test('saveReminder writes a reminder under the user path', () async {
      await repository.saveReminder(
        uid: uid,
        reminder: _buildReminder(
          userId: uid,
          medicationId: 'med-1',
          medicationName: 'Ibuprofen',
          hour: 9,
          minute: 15,
        ),
        reminderId: 'rem-1',
      );

      final snapshot = await FirestorePaths.reminderDoc(
        firestore,
        uid,
        'rem-1',
      ).get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), isNotNull);
      expect(snapshot.data()!['userId'], uid);
      expect(snapshot.data()!['medicationId'], 'med-1');
      expect(snapshot.data()!['createdAt'], isNotNull);
      expect(snapshot.data()!['updatedAt'], isNotNull);
    });

    test('listReminders filters by medicationId', () async {
      await FirestorePaths.remindersCollection(firestore, uid).doc('rem-a').set(
        _buildReminder(
          id: 'rem-a',
          userId: uid,
          medicationId: 'med-a',
          medicationName: 'Aspirin',
          hour: 8,
          minute: 0,
        ).toMap(),
      );
      await FirestorePaths.remindersCollection(firestore, uid).doc('rem-b').set(
        _buildReminder(
          id: 'rem-b',
          userId: uid,
          medicationId: 'med-b',
          medicationName: 'Ibuprofen',
          hour: 10,
          minute: 0,
        ).toMap(),
      );

      final reminders = await repository.listReminders(
        uid: uid,
        medicationId: 'med-b',
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.id, 'rem-b');
      expect(reminders.single.medicationName, 'Ibuprofen');
    });

    test('replaceMedicationReminders swaps only the target medication reminders', () async {
      await FirestorePaths.remindersCollection(firestore, uid).doc('old-1').set(
        _buildReminder(
          id: 'old-1',
          userId: uid,
          medicationId: 'med-target',
          medicationName: 'Target Medication',
          hour: 8,
          minute: 0,
        ).toMap(),
      );
      await FirestorePaths.remindersCollection(firestore, uid).doc('keep-1').set(
        _buildReminder(
          id: 'keep-1',
          userId: uid,
          medicationId: 'med-other',
          medicationName: 'Other Medication',
          hour: 11,
          minute: 0,
        ).toMap(),
      );

      await repository.replaceMedicationReminders(
        uid: uid,
        medicationId: 'med-target',
        reminders: [
          _buildReminder(
            id: 'new-1',
            userId: uid,
            medicationId: 'ignored-by-method',
            medicationName: 'Target Medication',
            hour: 9,
            minute: 0,
          ),
          _buildReminder(
            id: 'new-2',
            userId: uid,
            medicationId: 'ignored-by-method',
            medicationName: 'Target Medication',
            hour: 21,
            minute: 0,
          ),
        ],
      );

      final targetReminders = await repository.listReminders(
        uid: uid,
        medicationId: 'med-target',
      );
      final otherReminders = await repository.listReminders(
        uid: uid,
        medicationId: 'med-other',
      );

      expect(targetReminders.map((item) => item.id).toSet(), {'new-1', 'new-2'});
      expect(targetReminders.every((item) => item.medicationId == 'med-target'), isTrue);
      expect(otherReminders.map((item) => item.id), ['keep-1']);
    });

    test('deleteMedicationReminders removes only matching medication reminders', () async {
      await FirestorePaths.remindersCollection(firestore, uid).doc('delete-me').set(
        _buildReminder(
          id: 'delete-me',
          userId: uid,
          medicationId: 'med-target',
          medicationName: 'Target Medication',
          hour: 8,
          minute: 30,
        ).toMap(),
      );
      await FirestorePaths.remindersCollection(firestore, uid).doc('keep-me').set(
        _buildReminder(
          id: 'keep-me',
          userId: uid,
          medicationId: 'med-other',
          medicationName: 'Other Medication',
          hour: 12,
          minute: 0,
        ).toMap(),
      );

      await repository.deleteMedicationReminders(
        uid: uid,
        medicationId: 'med-target',
      );

      final targetReminders = await repository.listReminders(
        uid: uid,
        medicationId: 'med-target',
      );
      final otherReminders = await repository.listReminders(
        uid: uid,
        medicationId: 'med-other',
      );

      expect(targetReminders, isEmpty);
      expect(otherReminders.map((item) => item.id), ['keep-me']);
    });
  });
}

ReminderRecord _buildReminder({
  String? id,
  required String userId,
  required String medicationId,
  required String medicationName,
  required int hour,
  required int minute,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return ReminderRecord(
    id: id,
    userId: userId,
    medicationId: medicationId,
    medicationName: medicationName,
    slotIndex: 0,
    hour: hour,
    minute: minute,
    timezone: 'Asia/Jerusalem',
    isEnabled: true,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
