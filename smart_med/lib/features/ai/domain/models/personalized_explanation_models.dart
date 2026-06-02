class PersonalizedExplanationResponse {
  const PersonalizedExplanationResponse({
    required this.generatedAt,
    required this.source,
    required this.model,
    required this.promptVersion,
    required this.groundedOnly,
    required this.quickSummary,
    required this.overallSeverity,
    required this.cautionCount,
    required this.interactionCount,
    required this.saferBehaviorTips,
    required this.medicationBadges,
    required this.profileCompleteness,
    required this.overview,
    required this.medicationExplanations,
    required this.interactionAlerts,
    required this.personalizedRisks,
    required this.questionsForClinician,
    required this.missingInformation,
    required this.evidence,
  });

  final DateTime? generatedAt;
  final String source;
  final String? model;
  final String promptVersion;
  final bool groundedOnly;
  final String quickSummary;
  final String overallSeverity;
  final int cautionCount;
  final int interactionCount;
  final List<String> saferBehaviorTips;
  final List<MedicationBadgeItem> medicationBadges;
  final ProfileCompletenessItem profileCompleteness;
  final String overview;
  final List<MedicationExplanationItem> medicationExplanations;
  final List<ExplanationAlertItem> interactionAlerts;
  final List<ExplanationAlertItem> personalizedRisks;
  final List<String> questionsForClinician;
  final List<String> missingInformation;
  final List<EvidenceItem> evidence;

  factory PersonalizedExplanationResponse.fromMap(Map<String, dynamic> map) {
    return PersonalizedExplanationResponse(
      generatedAt: _dateTimeOrNull(map['generated_at']),
      source: map['source']?.toString() ?? 'firestore',
      model: map['model']?.toString(),
      promptVersion:
          map['prompt_version']?.toString() ?? 'grounded-firestore-v2',
      groundedOnly: map['grounded_only'] == true,
      quickSummary: map['quick_summary']?.toString() ?? '',
      overallSeverity: map['overall_severity']?.toString() ?? 'Low',
      cautionCount: _intOrZero(map['caution_count']),
      interactionCount: _intOrZero(map['interaction_count']),
      saferBehaviorTips: _stringList(map['safer_behavior_tips']),
      medicationBadges: _mapList(
        map['medication_badges'],
        MedicationBadgeItem.fromMap,
      ),
      profileCompleteness: ProfileCompletenessItem.fromMap(
        _mapOrEmpty(map['profile_completeness']),
      ),
      overview: map['overview']?.toString() ?? '',
      medicationExplanations: _mapList(
        map['medication_explanations'],
        MedicationExplanationItem.fromMap,
      ),
      interactionAlerts: _mapList(
        map['interaction_alerts'],
        ExplanationAlertItem.fromMap,
      ),
      personalizedRisks: _mapList(
        map['personalized_risks'],
        ExplanationAlertItem.fromMap,
      ),
      questionsForClinician: _stringList(map['questions_for_clinician']),
      missingInformation: _stringList(map['missing_information']),
      evidence: _mapList(map['evidence'], EvidenceItem.fromMap),
    );
  }

  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static int _intOrZero(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _mapOrEmpty(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value.map((item) => item.toString()).toList(growable: false);
  }

  static List<T> _mapList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    if (value is! List) {
      return <T>[];
    }

    return value
        .whereType<Map>()
        .map((item) => fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}

class DraftMedicationInput {
  const DraftMedicationInput({
    this.existingMedicationId,
    required this.name,
    this.genericName,
    this.brandName,
    this.doseAmount,
    this.doseUnit,
    this.frequencyPerDay,
    this.reminderTimes = const <String>[],
    this.startDate,
    this.instructions,
    this.notes,
    this.form,
    this.status = 'active',
    this.remindersEnabled = true,
  });

  final String? existingMedicationId;
  final String name;
  final String? genericName;
  final String? brandName;
  final double? doseAmount;
  final String? doseUnit;
  final int? frequencyPerDay;
  final List<String> reminderTimes;
  final DateTime? startDate;
  final String? instructions;
  final String? notes;
  final String? form;
  final String status;
  final bool remindersEnabled;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'existing_medication_id': existingMedicationId,
      'name': name,
      'generic_name': genericName,
      'brand_name': brandName,
      'dose_amount': doseAmount,
      'dose_unit': doseUnit,
      'frequency_per_day': frequencyPerDay,
      'reminder_times': reminderTimes,
      'start_date': startDate?.toIso8601String(),
      'instructions': instructions,
      'notes': notes,
      'form': form,
      'status': status,
      'reminders_enabled': remindersEnabled,
    }..removeWhere((key, value) => value == null);
  }
}

class MedicationExplanationItem {
  const MedicationExplanationItem({
    required this.medicationId,
    required this.name,
    required this.genericName,
    required this.explanation,
    required this.sourceIds,
  });

  final String medicationId;
  final String name;
  final String? genericName;
  final String explanation;
  final List<String> sourceIds;

  factory MedicationExplanationItem.fromMap(Map<String, dynamic> map) {
    return MedicationExplanationItem(
      medicationId: map['medication_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown medication',
      genericName: map['generic_name']?.toString(),
      explanation: map['explanation']?.toString() ?? '',
      sourceIds: PersonalizedExplanationResponse._stringList(map['source_ids']),
    );
  }
}

class MedicationBadgeItem {
  const MedicationBadgeItem({
    required this.medicationId,
    required this.label,
    required this.severity,
  });

  final String medicationId;
  final String label;
  final String severity;

  factory MedicationBadgeItem.fromMap(Map<String, dynamic> map) {
    return MedicationBadgeItem(
      medicationId: map['medication_id']?.toString() ?? '',
      label: map['label']?.toString() ?? 'Explained',
      severity: map['severity']?.toString() ?? 'Low',
    );
  }
}

class ProfileCompletenessItem {
  const ProfileCompletenessItem({
    required this.isComplete,
    required this.missingFields,
    required this.summary,
  });

  final bool isComplete;
  final List<String> missingFields;
  final String summary;

  factory ProfileCompletenessItem.fromMap(Map<String, dynamic> map) {
    return ProfileCompletenessItem(
      isComplete: map['is_complete'] == true,
      missingFields: PersonalizedExplanationResponse._stringList(
        map['missing_fields'],
      ),
      summary: map['summary']?.toString() ?? '',
    );
  }
}

class ExplanationAlertItem {
  const ExplanationAlertItem({
    required this.severity,
    required this.title,
    required this.detail,
    required this.sourceIds,
  });

  final String severity;
  final String title;
  final String detail;
  final List<String> sourceIds;

  factory ExplanationAlertItem.fromMap(Map<String, dynamic> map) {
    return ExplanationAlertItem(
      severity: map['severity']?.toString() ?? 'Info',
      title: map['title']?.toString() ?? 'Alert',
      detail: map['detail']?.toString() ?? '',
      sourceIds: PersonalizedExplanationResponse._stringList(map['source_ids']),
    );
  }
}

class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.detail,
  });

  final String id;
  final String sourceType;
  final String title;
  final String detail;

  factory EvidenceItem.fromMap(Map<String, dynamic> map) {
    return EvidenceItem(
      id: map['id']?.toString() ?? '',
      sourceType: map['source_type']?.toString() ?? 'unknown',
      title: map['title']?.toString() ?? 'Evidence',
      detail: map['detail']?.toString() ?? '',
    );
  }
}
