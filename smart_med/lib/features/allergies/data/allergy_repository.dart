import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/allergies/data/models/allergy_record.dart';

class AllergyRepository {
  AllergyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.allergiesCollection(_firestore, uid);
  }

  Stream<List<AllergyRecord>> watchAllergies({required String uid}) {
    return _collection(uid).orderBy('name').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => AllergyRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<List<AllergyRecord>> listAllergies({required String uid}) async {
    final snapshot = await _collection(uid).orderBy('name').get();
    return snapshot.docs
        .map((doc) => AllergyRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveAllergy({
    required String uid,
    required AllergyRecord allergy,
    String? allergyId,
  }) async {
    final docRef = allergyId == null
        ? _collection(uid).doc()
        : FirestorePaths.allergyDoc(_firestore, uid, allergyId);

    final existing = await docRef.get();
    final payload = allergy.toMap();
    payload['userId'] = uid;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (allergy.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<void> replaceAllergies({
    required String uid,
    required List<AllergyRecord> allergies,
  }) async {
    final collection = _collection(uid);
    final existing = await collection.get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final allergy in allergies) {
      final docRef = allergy.id == null ? collection.doc() : collection.doc(allergy.id);
      final payload = allergy.toMap();
      payload['userId'] = uid;
      payload['createdAt'] = allergy.createdAt ?? FieldValue.serverTimestamp();
      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, payload);
    }

    await batch.commit();
  }
}

final AllergyRepository allergyRepository = AllergyRepository();
