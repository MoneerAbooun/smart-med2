import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';

class MedicationRepository {
  MedicationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.medicationsCollection(_firestore, uid);
  }

  String createMedicationId({required String uid}) {
    return _collection(uid).doc().id;
  }

  Future<String> saveMedicationRecord({
    required String uid,
    required MedicationRecord medication,
    String? medicationId,
  }) async {
    final docRef = medicationId == null
        ? _collection(uid).doc()
        : FirestorePaths.medicationDoc(_firestore, uid, medicationId);

    final existing = await docRef.get();
    final payload = medication.toMap();
    payload['userId'] = uid;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (medication.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
    return docRef.id;
  }

  Future<String> createMedication({
    required String uid,
    required MedicationRecord medication,
  }) {
    return saveMedicationRecord(uid: uid, medication: medication);
  }

  Future<void> updateMedicationRecord({
    required String uid,
    required String medicationId,
    required MedicationRecord medication,
  }) async {
    await saveMedicationRecord(
      uid: uid,
      medication: medication,
      medicationId: medicationId,
    );
  }

  Stream<List<MedicationRecord>> watchMedicationRecords({required String uid}) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationRecord.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<MedicationRecord?> fetchMedicationRecord({
    required String uid,
    required String medicationId,
  }) async {
    final snapshot = await getMedication(uid: uid, medicationId: medicationId);
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return MedicationRecord.fromMap(snapshot.id, snapshot.data()!);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> medicationsStream({
    required String uid,
  }) {
    return _collection(uid).orderBy('createdAt', descending: true).snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addMedication({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final docRef = _collection(uid).doc();
    final record = MedicationRecord.fromMap(docRef.id, {
      ...data,
      'userId': uid,
    });

    await saveMedicationRecord(
      uid: uid,
      medication: record,
      medicationId: docRef.id,
    );

    return docRef;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMedication({
    required String uid,
    required String medicationId,
  }) {
    return FirestorePaths.medicationDoc(_firestore, uid, medicationId).get();
  }

  Future<void> updateMedication({
    required String uid,
    required String medicationId,
    required Map<String, dynamic> data,
  }) async {
    final existing = await getMedication(uid: uid, medicationId: medicationId);
    final mergedData = {...?existing.data(), ...data, 'userId': uid};
    final record = MedicationRecord.fromMap(medicationId, mergedData);

    await saveMedicationRecord(
      uid: uid,
      medication: record,
      medicationId: medicationId,
    );
  }

  Future<void> deleteMedication({
    required String uid,
    required String medicationId,
  }) {
    return FirestorePaths.medicationDoc(_firestore, uid, medicationId).delete();
  }
}

final MedicationRepository medicationRepository = MedicationRepository();
