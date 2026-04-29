import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/reminders/data/models/reminder_record.dart';

class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.remindersCollection(_firestore, uid);
  }

  Stream<List<ReminderRecord>> watchReminders({
    required String uid,
    String? medicationId,
  }) {
    Query<Map<String, dynamic>> query = _collection(uid).orderBy('hour');

    if (medicationId != null && medicationId.trim().isNotEmpty) {
      query = query.where('medicationId', isEqualTo: medicationId.trim());
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ReminderRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<List<ReminderRecord>> listReminders({
    required String uid,
    String? medicationId,
  }) async {
    Query<Map<String, dynamic>> query = _collection(uid);

    if (medicationId != null && medicationId.trim().isNotEmpty) {
      query = query.where('medicationId', isEqualTo: medicationId.trim());
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ReminderRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveReminder({
    required String uid,
    required ReminderRecord reminder,
    String? reminderId,
  }) async {
    final docRef = reminderId == null
        ? _collection(uid).doc()
        : FirestorePaths.reminderDoc(_firestore, uid, reminderId);

    final existing = await docRef.get();
    final payload = reminder.toMap();
    payload['userId'] = uid;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (reminder.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<void> replaceMedicationReminders({
    required String uid,
    required String medicationId,
    required List<ReminderRecord> reminders,
  }) async {
    final query = await _collection(
      uid,
    ).where('medicationId', isEqualTo: medicationId).get();
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }

    final collection = _collection(uid);
    for (final reminder in reminders) {
      final docRef = reminder.id == null ? collection.doc() : collection.doc(reminder.id);
      final payload = reminder.toMap();
      payload['userId'] = uid;
      payload['medicationId'] = medicationId;
      payload['createdAt'] = reminder.createdAt ?? FieldValue.serverTimestamp();
      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, payload);
    }

    await batch.commit();
  }

  Future<void> deleteMedicationReminders({
    required String uid,
    required String medicationId,
  }) async {
    final query = await _collection(
      uid,
    ).where('medicationId', isEqualTo: medicationId).get();
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

final ReminderRepository reminderRepository = ReminderRepository();
