import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';

void main() {
  group('MedicationRepository', () {
    late FakeFirebaseFirestore firestore;
    late MedicationRepository repository;

    const uid = 'user-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MedicationRepository(firestore: firestore);
    });

    test('createMedication writes a document with audit fields', () async {
      final medication = _buildMedication(
        userId: uid,
        name: 'Ibuprofen',
        createdAt: DateTime.utc(2026, 4, 1, 8),
      );

      final medicationId = await repository.createMedication(
        uid: uid,
        medication: medication,
      );

      final snapshot = await FirestorePaths.medicationDoc(
        firestore,
        uid,
        medicationId,
      ).get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), isNotNull);
      expect(snapshot.data()!['userId'], uid);
      expect(snapshot.data()!['name'], 'Ibuprofen');
      expect(snapshot.data()!['createdAt'], isNotNull);
      expect(snapshot.data()!['updatedAt'], isNotNull);
    });

    test('fetchMedicationRecord returns null when the document is missing', () async {
      final record = await repository.fetchMedicationRecord(
        uid: uid,
        medicationId: 'missing-id',
      );

      expect(record, isNull);
    });

    test('updateMedication keeps createdAt and updates changed fields', () async {
      const medicationId = 'med-001';
      final createdAt = DateTime.utc(2026, 3, 15, 9, 30);

      await FirestorePaths.medicationDoc(firestore, uid, medicationId).set({
        ..._buildMedication(
          id: medicationId,
          userId: uid,
          name: 'Vitamin C',
          createdAt: createdAt,
          updatedAt: createdAt,
        ).toMap(),
        'userId': uid,
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });

      await repository.updateMedication(
        uid: uid,
        medicationId: medicationId,
        data: {
          'name': 'Vitamin C 1000',
          'doseAmount': 1000,
          'doseUnit': 'mg',
          'notes': 'Take after breakfast',
        },
      );

      final updated = await repository.fetchMedicationRecord(
        uid: uid,
        medicationId: medicationId,
      );

      expect(updated, isNotNull);
      expect(updated!.name, 'Vitamin C 1000');
      expect(updated.doseAmount, 1000);
      expect(updated.doseUnit, 'mg');
      expect(updated.notes, 'Take after breakfast');
      expect(updated.createdAt, isNotNull);
      expect(updated.createdAt!.isAtSameMomentAs(createdAt), isTrue);
      expect(updated.updatedAt, isNotNull);
      expect(updated.updatedAt!.isAfter(createdAt), isTrue);
    });

    test('watchMedicationRecords sorts results by createdAt descending', () async {
      await FirestorePaths.medicationsCollection(firestore, uid).doc('older').set({
        ..._buildMedication(
          id: 'older',
          userId: uid,
          name: 'Older',
          createdAt: DateTime.utc(2026, 1, 1, 8),
        ).toMap(),
        'createdAt': DateTime.utc(2026, 1, 1, 8),
        'updatedAt': DateTime.utc(2026, 1, 1, 8),
      });

      await FirestorePaths.medicationsCollection(firestore, uid).doc('newer').set({
        ..._buildMedication(
          id: 'newer',
          userId: uid,
          name: 'Newer',
          createdAt: DateTime.utc(2026, 2, 1, 8),
        ).toMap(),
        'createdAt': DateTime.utc(2026, 2, 1, 8),
        'updatedAt': DateTime.utc(2026, 2, 1, 8),
      });

      final records = await repository.watchMedicationRecords(uid: uid).first;

      expect(records.map((record) => record.id), ['newer', 'older']);
    });

    test('deleteMedication removes the stored document', () async {
      const medicationId = 'med-delete';
      await FirestorePaths.medicationDoc(firestore, uid, medicationId).set({
        ..._buildMedication(id: medicationId, userId: uid).toMap(),
        'userId': uid,
      });

      await repository.deleteMedication(uid: uid, medicationId: medicationId);

      final snapshot = await FirestorePaths.medicationDoc(
        firestore,
        uid,
        medicationId,
      ).get();

      expect(snapshot.exists, isFalse);
    });
  });
}

MedicationRecord _buildMedication({
  String? id,
  required String userId,
  String name = 'Sample Medication',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return MedicationRecord(
    id: id,
    userId: userId,
    name: name,
    doseAmount: 200,
    doseUnit: 'mg',
    frequencyPerDay: 1,
    scheduledTimes: const [
      MedicationScheduleTime(hour: 8, minute: 0),
    ],
    remindersEnabled: true,
    status: 'active',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
