import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medications/domain/models/medication_dose_history_record.dart';

class MedicationDoseHistoryRepository {
  MedicationDoseHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.medicationHistoryCollection(_firestore, uid);
  }

  String documentIdForDoseKey(String doseKey) {
    return base64Url.encode(utf8.encode(doseKey)).replaceAll('=', '');
  }

  Stream<List<MedicationDoseHistoryRecord>> watchRecent({
    required String uid,
    int limit = 20,
  }) {
    return _collection(uid)
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    MedicationDoseHistoryRecord.fromMap(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<List<MedicationDoseHistoryRecord>> watchScheduledWindow({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    return _collection(uid)
        .where('scheduledAt', isGreaterThanOrEqualTo: start)
        .where('scheduledAt', isLessThan: end)
        .orderBy('scheduledAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    MedicationDoseHistoryRecord.fromMap(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  Future<List<MedicationDoseHistoryRecord>> listRecent({
    required String uid,
    int limit = 20,
  }) async {
    final snapshot = await _collection(
      uid,
    ).orderBy('recordedAt', descending: true).limit(limit).get();

    return snapshot.docs
        .map((doc) => MedicationDoseHistoryRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveEntry({
    required String uid,
    required MedicationDoseHistoryRecord entry,
  }) async {
    final docRef = _collection(uid).doc(documentIdForDoseKey(entry.doseKey));
    final existing = await docRef.get();
    final payload = entry.toMap();
    payload['userId'] = uid;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (entry.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }
}

final MedicationDoseHistoryRepository medicationDoseHistoryRepository =
    MedicationDoseHistoryRepository();
