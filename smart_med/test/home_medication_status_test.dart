import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/features/home/domain/home_medication_status.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';

void main() {
  group('HomeMedicationStatus', () {
    test('counts future-start medicines as current regimen medicines', () {
      final today = DateTime(2026, 6, 3, 12);
      final tomorrow = DateTime(2026, 6, 4);
      final medication = _buildMedication(startDate: tomorrow);

      expect(
        HomeMedicationStatus.currentRegimen([medication], onDate: today),
        contains(medication),
      );
      expect(
        HomeMedicationStatus.scheduledOn([medication], date: today),
        isEmpty,
      );
      expect(
        HomeMedicationStatus.scheduledOn([medication], date: tomorrow),
        contains(medication),
      );
    });

    test('excludes medicines that ended before today', () {
      final today = DateTime(2026, 6, 3, 12);
      final medication = _buildMedication(endDate: DateTime(2026, 6, 2));

      expect(
        HomeMedicationStatus.currentRegimen([medication], onDate: today),
        isEmpty,
      );
    });

    test('excludes inactive medicines from current and scheduled lists', () {
      final today = DateTime(2026, 6, 3, 12);
      final medication = _buildMedication(status: 'paused');

      expect(
        HomeMedicationStatus.currentRegimen([medication], onDate: today),
        isEmpty,
      );
      expect(
        HomeMedicationStatus.scheduledOn([medication], date: today),
        isEmpty,
      );
    });
  });
}

MedicationRecord _buildMedication({
  DateTime? startDate,
  DateTime? endDate,
  String status = 'active',
}) {
  return MedicationRecord(
    userId: 'user-123',
    name: 'Acamol',
    doseAmount: 656,
    doseUnit: 'mg',
    frequencyPerDay: 1,
    scheduledTimes: const [MedicationScheduleTime(hour: 17, minute: 39)],
    startDate: startDate,
    endDate: endDate,
    remindersEnabled: true,
    status: status,
  );
}
