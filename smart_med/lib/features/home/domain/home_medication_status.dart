import 'package:smart_med/features/medications/domain/models/medication_record.dart';

class HomeMedicationStatus {
  const HomeMedicationStatus._();

  static DateTime startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  static bool isInCurrentRegimen(
    MedicationRecord medication, {
    required DateTime onDate,
  }) {
    if (medication.status.trim().toLowerCase() != 'active') {
      return false;
    }

    final dayStart = startOfDay(onDate);
    final endDate = medication.endDate;

    return endDate == null || !endDate.isBefore(dayStart);
  }

  static bool hasScheduledDoseOn(
    MedicationRecord medication, {
    required DateTime date,
  }) {
    if (medication.scheduledTimes.isEmpty) {
      return false;
    }

    if (!isInCurrentRegimen(medication, onDate: date)) {
      return false;
    }

    final startDate = medication.startDate;
    return startDate == null || !startDate.isAfter(endOfDay(date));
  }

  static List<MedicationRecord> currentRegimen(
    List<MedicationRecord> medications, {
    required DateTime onDate,
  }) {
    return medications
        .where((medication) {
          return isInCurrentRegimen(medication, onDate: onDate);
        })
        .toList(growable: false);
  }

  static List<MedicationRecord> scheduledOn(
    List<MedicationRecord> medications, {
    required DateTime date,
  }) {
    return medications
        .where((medication) {
          return hasScheduledDoseOn(medication, date: date);
        })
        .toList(growable: false);
  }
}
