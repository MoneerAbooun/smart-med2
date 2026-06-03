import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';
import 'package:smart_med/features/medications/domain/models/medication_safety_assessment.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';
import 'package:smart_med/models/local_medicine.dart';

class MedicationSafetyAssessmentService {
  MedicationSafetyAssessmentService({
    ProfileRepository? profileRepository,
    MedicineLookupRepository? medicineLookupRepository,
    DrugInteractionLookupRepository? interactionLookupRepository,
  }) : _profileRepository = profileRepository ?? profileRepositoryInstance,
       _medicineLookupRepository =
           medicineLookupRepository ?? medicineLookupRepositoryInstance,
       _interactionLookupRepository =
           interactionLookupRepository ?? interactionLookupRepositoryInstance;

  final ProfileRepository _profileRepository;
  final MedicineLookupRepository _medicineLookupRepository;
  final DrugInteractionLookupRepository _interactionLookupRepository;

  Future<MedicationSafetyAssessment> assessMedicine({
    required String uid,
    required LocalMedicine medicine,
  }) async {
    final medicineName = _displayMedicineName(medicine);
    final medicineKey = medicationSafetyKey(medicine);
    final signals = <MedicationSafetySignal>[];
    final notes = <String>[];

    final profile = await _profileRepository.fetchProfile(uid: uid);
    if (profile == null) {
      notes.add('We could not find your safety profile for this check.');
      return MedicationSafetyAssessment(
        medicineKey: medicineKey,
        medicineName: medicineName,
        signals: signals,
        notes: notes,
      );
    }

    final medicineAliases = _medicineAliases(medicine);
    final directAllergyKeys = <String>{};

    for (final allergy in profile.allergyNames) {
      if (_matchesAnyAlias(allergy, medicineAliases)) {
        directAllergyKeys.add(_normalizeForComparison(allergy));
        signals.add(
          MedicationSafetySignal(
            type: MedicationSafetySignalType.directAllergy,
            severity: 'High',
            title: 'Drug allergy match',
            detail:
                '$medicineName matches the drug allergy "$allergy" in your profile.',
            matchedProfileItem: allergy,
          ),
        );
      }
    }

    MedicineLookupResult? medicineInformation;
    try {
      medicineInformation = await _medicineLookupRepository.searchByName(
        _medicineLookupName(medicine),
      );
    } on MedicineLookupRepositoryException catch (error) {
      notes.add(
        'Public medicine label warnings could not be checked: ${error.message}',
      );
    } catch (error) {
      notes.add('Public medicine label warnings could not be checked: $error');
    }

    if (medicineInformation != null) {
      signals.addAll(
        _buildAllergyWarningSignals(
          allergies: profile.allergyNames,
          medicineName: medicineName,
          medicineInformation: medicineInformation,
        ),
      );
      signals.addAll(
        _buildConditionWarningSignals(
          profile: profile,
          medicineName: medicineName,
          medicineInformation: medicineInformation,
        ),
      );
    }

    for (final allergy in profile.allergyNames) {
      final allergyKey = _normalizeForComparison(allergy);
      if (allergyKey.isEmpty || directAllergyKeys.contains(allergyKey)) {
        continue;
      }

      try {
        final result = await _interactionLookupRepository.checkInteraction(
          firstDrugName: _medicineLookupName(medicine),
          secondDrugName: allergy,
        );

        if (_hasInteractionSignal(result)) {
          signals.add(
            MedicationSafetySignal(
              type: MedicationSafetySignalType.allergyInteraction,
              severity: _normalizedSeverity(result.severity),
              title: 'Possible allergy-drug interaction',
              detail:
                  '$medicineName may interact with the allergy medicine "$allergy": ${result.summary}',
              matchedProfileItem: allergy,
              sourceSummary: result.summary,
              evidence: <String>[
                ...result.warnings,
                ...result.recommendations,
                ...result.evidence,
              ],
            ),
          );
        }
      } on DrugInteractionLookupRepositoryException catch (error) {
        notes.add(
          'Could not compare $medicineName with allergy "$allergy": ${error.message}',
        );
      } catch (error) {
        notes.add('Could not compare $medicineName with allergy "$allergy".');
      }
    }

    return MedicationSafetyAssessment(
      medicineKey: medicineKey,
      medicineName: medicineName,
      signals: _dedupeSignals(signals),
      notes: _dedupeStrings(notes),
    );
  }

  List<MedicationSafetySignal> _buildAllergyWarningSignals({
    required List<String> allergies,
    required String medicineName,
    required MedicineLookupResult medicineInformation,
  }) {
    final warningItems = _safetyTextItems(medicineInformation);
    final signals = <MedicationSafetySignal>[];

    for (final allergy in allergies) {
      final aliases = _profileItemAliases(allergy);
      final matches = _matchingEvidence(warningItems, aliases);
      if (matches.isEmpty) {
        continue;
      }

      signals.add(
        MedicationSafetySignal(
          type: MedicationSafetySignalType.allergyWarning,
          severity: 'High',
          title: 'Drug allergy warning',
          detail:
              'Public label text for $medicineName mentions "$allergy" in safety warnings.',
          matchedProfileItem: allergy,
          evidence: matches,
        ),
      );
    }

    return signals;
  }

  List<MedicationSafetySignal> _buildConditionWarningSignals({
    required UserProfileRecord profile,
    required String medicineName,
    required MedicineLookupResult medicineInformation,
  }) {
    final warningItems = _safetyTextItems(medicineInformation);
    final conditions = <String>[
      ...profile.medicalConditionNames,
      if (profile.isPregnant) 'Pregnancy',
      if (profile.isBreastfeeding) 'Breastfeeding',
    ];
    final signals = <MedicationSafetySignal>[];

    for (final condition in conditions) {
      final aliases = _profileItemAliases(condition);
      final matches = _matchingEvidence(warningItems, aliases);
      if (matches.isEmpty) {
        continue;
      }

      signals.add(
        MedicationSafetySignal(
          type: MedicationSafetySignalType.chronicConditionWarning,
          severity: 'Moderate',
          title: 'Condition warning',
          detail:
              'Public label text for $medicineName mentions "$condition" in safety warnings.',
          matchedProfileItem: condition,
          evidence: matches,
        ),
      );
    }

    return signals;
  }

  List<String> _safetyTextItems(MedicineLookupResult result) {
    return _dedupeStrings(<String>[
      ...result.warnings,
      ...result.interactions,
      ...result.dose,
      ...result.disclaimer,
    ]);
  }

  List<String> _matchingEvidence(List<String> items, Set<String> aliases) {
    final matches = <String>[];
    for (final item in items) {
      if (_textMentionsAnyAlias(item, aliases)) {
        matches.add(item);
      }

      if (matches.length >= 3) {
        break;
      }
    }

    return List<String>.unmodifiable(matches);
  }

  bool _hasInteractionSignal(DrugInteractionLookupResult result) {
    final severity = result.severity.trim().toLowerCase();
    return severity.isNotEmpty &&
        severity != 'none' &&
        severity != 'no interaction' &&
        severity != 'no known interaction' &&
        severity != 'no specific interaction found';
  }

  String _normalizedSeverity(String value) {
    final severity = value.trim();
    if (severity.isEmpty) {
      return 'Unknown';
    }

    final normalized = severity.toLowerCase();
    if (normalized == 'major' || normalized == 'severe') {
      return 'High';
    }

    return severity;
  }

  bool _matchesAnyAlias(String profileValue, Set<String> medicineAliases) {
    final profileAliases = _profileItemAliases(profileValue);
    for (final profileAlias in profileAliases) {
      if (medicineAliases.contains(profileAlias)) {
        return true;
      }
    }

    return false;
  }

  bool _textMentionsAnyAlias(String value, Set<String> aliases) {
    final normalizedText = _normalizeForTextSearch(value);
    if (normalizedText.isEmpty) {
      return false;
    }

    for (final alias in aliases) {
      if (_aliasIsSearchable(alias) &&
          RegExp(
            r'(^|\s)' + RegExp.escape(alias) + r'(\s|$)',
          ).hasMatch(normalizedText)) {
        return true;
      }
    }

    return false;
  }

  Set<String> _medicineAliases(LocalMedicine medicine) {
    final aliases = <String>{};

    void add(String? value) {
      final normalized = _normalizeForComparison(value);
      if (normalized.isNotEmpty) {
        aliases.add(normalized);
      }
    }

    void addSplit(String? value) {
      add(value);
      for (final part in _splitCombinedName(value)) {
        add(part);
      }
    }

    add(medicine.id);
    addSplit(medicine.brandName);
    addSplit(medicine.genericName);

    for (final ingredient in medicine.activeIngredients) {
      addSplit(ingredient);
    }

    for (final name in medicine.searchNames) {
      addSplit(name);
    }

    return aliases;
  }

  Set<String> _profileItemAliases(String value) {
    final aliases = <String>{};

    void add(String? candidate) {
      final normalized = _normalizeForComparison(candidate);
      if (normalized.isNotEmpty) {
        aliases.add(normalized);
      }
    }

    add(value);
    for (final part in _splitCombinedName(value)) {
      add(part);
    }

    final parenthetical = RegExp(r'\(([^)]+)\)').firstMatch(value);
    if (parenthetical != null) {
      add(parenthetical.group(1));
    }

    final withoutParentheses = value.replaceAll(RegExp(r'\s*\([^)]+\)'), '');
    add(withoutParentheses);

    for (final synonym
        in _conditionSynonyms[_normalizeForComparison(value)] ??
            const <String>[]) {
      add(synonym);
    }

    return aliases;
  }

  List<String> _splitCombinedName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const <String>[];
    }

    return text
        .split(RegExp(r'\s*(?:\+|/|,|;|\band\b)\s*', caseSensitive: false))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _aliasIsSearchable(String alias) {
    if (alias.length >= 4) {
      return true;
    }

    return const <String>{'ibs', 'copd', 'hiv', 'aids'}.contains(alias);
  }

  String _medicineLookupName(LocalMedicine medicine) {
    return _cleanText(medicine.genericName) ??
        _cleanText(medicine.brandName) ??
        _displayMedicineName(medicine);
  }

  String _displayMedicineName(LocalMedicine medicine) {
    return _cleanText(medicine.brandName) ??
        _cleanText(medicine.genericName) ??
        'Unknown medicine';
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  List<MedicationSafetySignal> _dedupeSignals(
    List<MedicationSafetySignal> signals,
  ) {
    final seen = <String>{};
    final result = <MedicationSafetySignal>[];

    for (final signal in signals) {
      final key = <String>[
        signal.type.name,
        signal.severity,
        signal.matchedProfileItem ?? '',
        signal.detail,
      ].map(_normalizeForComparison).join('|');

      if (seen.add(key)) {
        result.add(signal);
      }
    }

    return List<MedicationSafetySignal>.unmodifiable(result);
  }

  List<String> _dedupeStrings(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final text = value.trim();
      if (text.isEmpty) {
        continue;
      }

      final key = text.toLowerCase();
      if (seen.add(key)) {
        result.add(text);
      }
    }

    return List<String>.unmodifiable(result);
  }

  String _normalizeForComparison(String? value) {
    return _normalizeForTextSearch(value)
        .replaceAll(RegExp(r'\bacid\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeForTextSearch(String? value) {
    final text = value?.toLowerCase() ?? '';
    return text
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

String medicationSafetyKey(LocalMedicine medicine) {
  final values = <String?>[
    medicine.id,
    medicine.brandName,
    medicine.genericName,
    medicine.activeIngredients.join('|'),
  ];

  return values
      .map((value) => value?.trim().toLowerCase() ?? '')
      .where((value) => value.isNotEmpty)
      .join('|');
}

const Map<String, List<String>> _conditionSynonyms = <String, List<String>>{
  'diabetes': <String>[
    'diabetes',
    'diabetic',
    'blood glucose',
    'hypoglycemia',
    'hyperglycemia',
  ],
  'hypertension': <String>[
    'hypertension',
    'high blood pressure',
    'blood pressure',
  ],
  'asthma': <String>['asthma', 'bronchospasm'],
  'heart disease': <String>[
    'heart disease',
    'cardiac disease',
    'cardiac',
    'heart failure',
  ],
  'coronary artery disease': <String>[
    'coronary artery disease',
    'coronary heart disease',
    'ischemic heart disease',
  ],
  'chronic kidney disease': <String>[
    'chronic kidney disease',
    'kidney disease',
    'renal disease',
    'renal impairment',
    'kidney failure',
  ],
  'chronic obstructive pulmonary disease copd': <String>[
    'chronic obstructive pulmonary disease',
    'copd',
  ],
  'epilepsy': <String>['epilepsy', 'seizure', 'seizures'],
  'glaucoma': <String>['glaucoma', 'intraocular pressure'],
  'gout': <String>['gout', 'hyperuricemia'],
  'hepatitis': <String>[
    'hepatitis',
    'liver disease',
    'hepatic disease',
    'hepatic impairment',
  ],
  'hiv aids': <String>['hiv', 'aids'],
  'irritable bowel syndrome ibs': <String>['irritable bowel syndrome', 'ibs'],
  'pregnancy': <String>['pregnancy', 'pregnant'],
  'breastfeeding': <String>['breastfeeding', 'breast feeding', 'lactation'],
};

final ProfileRepository profileRepositoryInstance = profileRepository;
final MedicineLookupRepository medicineLookupRepositoryInstance =
    medicineLookupRepository;
final DrugInteractionLookupRepository interactionLookupRepositoryInstance =
    drugInteractionLookupRepository;

final MedicationSafetyAssessmentService medicationSafetyAssessmentService =
    MedicationSafetyAssessmentService();
