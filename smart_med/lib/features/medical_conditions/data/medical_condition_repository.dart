import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medical_conditions/data/models/medical_condition_record.dart';

class MedicalConditionRepository {
  MedicalConditionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.medicalConditionsCollection(_firestore, uid);
  }

  Stream<List<MedicalConditionRecord>> watchConditions({required String uid}) {
    return _collection(uid).orderBy('name').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => MedicalConditionRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<List<MedicalConditionRecord>> listConditions({
    required String uid,
  }) async {
    final snapshot = await _collection(uid).orderBy('name').get();
    return snapshot.docs
        .map((doc) => MedicalConditionRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveCondition({
    required String uid,
    required MedicalConditionRecord condition,
    String? conditionId,
  }) async {
    final docRef = conditionId == null
        ? _collection(uid).doc()
        : FirestorePaths.medicalConditionDoc(_firestore, uid, conditionId);

    final existing = await docRef.get();
    final payload = condition.toMap();
    payload['userId'] = uid;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (condition.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<void> replaceConditions({
    required String uid,
    required List<MedicalConditionRecord> conditions,
  }) async {
    final collection = _collection(uid);
    final existing = await collection.get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final condition in conditions) {
      final docRef = condition.id == null
          ? collection.doc()
          : collection.doc(condition.id);
      final payload = condition.toMap();
      payload['userId'] = uid;
      payload['createdAt'] =
          condition.createdAt ?? FieldValue.serverTimestamp();
      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, payload);
    }

    await batch.commit();
  }
}

final MedicalConditionRepository medicalConditionRepository =
    MedicalConditionRepository();
