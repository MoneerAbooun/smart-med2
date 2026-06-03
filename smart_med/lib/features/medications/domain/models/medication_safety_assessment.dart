class MedicationSafetyAssessment {
  const MedicationSafetyAssessment({
    required this.medicineKey,
    required this.medicineName,
    required this.signals,
    this.notes = const <String>[],
  });

  final String medicineKey;
  final String medicineName;
  final List<MedicationSafetySignal> signals;
  final List<String> notes;

  bool get hasSignals => signals.isNotEmpty;

  bool get needsConfirmation {
    return signals.any((signal) => signal.requiresConfirmation);
  }
}

class MedicationSafetySignal {
  const MedicationSafetySignal({
    required this.type,
    required this.severity,
    required this.title,
    required this.detail,
    this.matchedProfileItem,
    this.sourceSummary,
    this.evidence = const <String>[],
  });

  final MedicationSafetySignalType type;
  final String severity;
  final String title;
  final String detail;
  final String? matchedProfileItem;
  final String? sourceSummary;
  final List<String> evidence;

  bool get requiresConfirmation {
    final normalized = severity.trim().toLowerCase();
    return normalized == 'high' ||
        normalized == 'major' ||
        normalized == 'severe' ||
        normalized == 'moderate' ||
        normalized == 'low' ||
        normalized == 'unknown';
  }
}

enum MedicationSafetySignalType {
  directAllergy,
  allergyInteraction,
  allergyWarning,
  chronicConditionWarning,
}
