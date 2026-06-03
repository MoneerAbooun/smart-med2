import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/medications/data/repositories/medication_dose_history_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_dose_history_record.dart';

void main() {
  group('MedicationDoseHistoryRepository', () {
    late FakeFirebaseFirestore firestore;
    late MedicationDoseHistoryRepository repository;

    const uid = 'user-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MedicationDoseHistoryRepository(firestore: firestore);
    });

    test('saveEntry stores a taken dose history record', () async {
      final entry = _buildHistoryEntry(
        userId: uid,
        status: MedicationDoseHistoryRecord.statusTaken,
      );

      await repository.saveEntry(uid: uid, entry: entry);

      final history = await repository.listRecent(uid: uid);

      expect(history, hasLength(1));
      expect(history.single.userId, uid);
      expect(history.single.medicationName, 'Acamol');
      expect(history.single.status, MedicationDoseHistoryRecord.statusTaken);
      expect(history.single.scheduledAt.toUtc(), entry.scheduledAt.toUtc());
      expect(history.single.recordedAt.toUtc(), entry.recordedAt.toUtc());
    });

    test(
      'saveEntry updates the same scheduled dose instead of duplicating it',
      () async {
        final taken = _buildHistoryEntry(
          userId: uid,
          status: MedicationDoseHistoryRecord.statusTaken,
        );
        final skipped = _buildHistoryEntry(
          userId: uid,
          status: MedicationDoseHistoryRecord.statusSkipped,
          recordedAt: DateTime.utc(2026, 6, 3, 8, 10),
        );

        await repository.saveEntry(uid: uid, entry: taken);
        await repository.saveEntry(uid: uid, entry: skipped);

        final snapshot = await FirestorePaths.medicationHistoryCollection(
          firestore,
          uid,
        ).get();
        final history = await repository.listRecent(uid: uid);

        expect(snapshot.docs, hasLength(1));
        expect(history, hasLength(1));
        expect(
          history.single.status,
          MedicationDoseHistoryRecord.statusSkipped,
        );
        expect(history.single.recordedAt.toUtc(), skipped.recordedAt.toUtc());
      },
    );

    test(
      'watchScheduledWindow returns only doses in the requested window',
      () async {
        final inside = _buildHistoryEntry(
          userId: uid,
          doseKey: 'med-001-2026-6-3-8-0',
          scheduledAt: DateTime.utc(2026, 6, 3, 8),
        );
        final outside = _buildHistoryEntry(
          userId: uid,
          doseKey: 'med-001-2026-6-5-8-0',
          scheduledAt: DateTime.utc(2026, 6, 5, 8),
        );

        await repository.saveEntry(uid: uid, entry: inside);
        await repository.saveEntry(uid: uid, entry: outside);

        final history = await repository
            .watchScheduledWindow(
              uid: uid,
              start: DateTime.utc(2026, 6, 3),
              end: DateTime.utc(2026, 6, 4),
            )
            .first;

        expect(history.map((entry) => entry.doseKey), [inside.doseKey]);
      },
    );
  });
}

MedicationDoseHistoryRecord _buildHistoryEntry({
  required String userId,
  String doseKey = 'med-001-2026-6-3-8-0',
  DateTime? scheduledAt,
  DateTime? recordedAt,
  String status = MedicationDoseHistoryRecord.statusTaken,
}) {
  return MedicationDoseHistoryRecord(
    userId: userId,
    doseKey: doseKey,
    medicationId: 'med-001',
    medicationName: 'Acamol',
    dosage: '656 mg',
    doseAmount: 656,
    doseUnit: 'mg',
    scheduledAt: scheduledAt ?? DateTime.utc(2026, 6, 3, 8),
    recordedAt: recordedAt ?? DateTime.utc(2026, 6, 3, 8, 5),
    status: status,
  );
}
