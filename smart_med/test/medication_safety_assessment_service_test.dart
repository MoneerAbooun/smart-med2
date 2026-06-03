import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';
import 'package:smart_med/features/medications/data/services/medication_safety_assessment_service.dart';
import 'package:smart_med/features/medications/domain/models/medication_safety_assessment.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';
import 'package:smart_med/models/local_medicine.dart';

void main() {
  group('MedicationSafetyAssessmentService', () {
    test(
      'flags a selected medicine that matches a profile drug allergy',
      () async {
        final interactionRepository = _FakeInteractionLookupRepository();
        final service = MedicationSafetyAssessmentService(
          profileRepository: _FakeProfileRepository(
            _profile(allergyNames: const <String>['Ibuprofen']),
          ),
          medicineLookupRepository: _FakeMedicineLookupRepository(
            result: _medicineLookupResult(),
          ),
          interactionLookupRepository: interactionRepository,
        );

        final assessment = await service.assessMedicine(
          uid: 'user-1',
          medicine: const LocalMedicine(
            brandName: 'Nurofen',
            genericName: 'Ibuprofen',
          ),
        );

        expect(assessment.needsConfirmation, isTrue);
        expect(assessment.signals, hasLength(1));
        expect(
          assessment.signals.single.type,
          MedicationSafetySignalType.directAllergy,
        );
        expect(interactionRepository.calls, isEmpty);
      },
    );

    test('flags interaction results against a profile drug allergy', () async {
      final service = MedicationSafetyAssessmentService(
        profileRepository: _FakeProfileRepository(
          _profile(allergyNames: const <String>['Warfarin']),
        ),
        medicineLookupRepository: _FakeMedicineLookupRepository(
          result: _medicineLookupResult(),
        ),
        interactionLookupRepository: _FakeInteractionLookupRepository(
          result: const DrugInteractionLookupResult(
            firstQuery: 'Ibuprofen',
            secondQuery: 'Warfarin',
            firstDrug: 'Ibuprofen',
            secondDrug: 'Warfarin',
            severity: 'High',
            summary: 'This combination can increase bleeding risk.',
            warnings: <String>['Watch for unusual bleeding.'],
            recommendations: <String>[
              'Review this combination with a clinician.',
            ],
            evidence: <String>['Curated safety rule matched.'],
            source: 'test',
          ),
        ),
      );

      final assessment = await service.assessMedicine(
        uid: 'user-1',
        medicine: const LocalMedicine(genericName: 'Ibuprofen'),
      );

      expect(assessment.needsConfirmation, isTrue);
      expect(
        assessment.signals.single.type,
        MedicationSafetySignalType.allergyInteraction,
      );
      expect(assessment.signals.single.matchedProfileItem, 'Warfarin');
    });

    test('flags chronic conditions mentioned in medicine warnings', () async {
      final service = MedicationSafetyAssessmentService(
        profileRepository: _FakeProfileRepository(
          _profile(
            medicalConditionNames: const <String>['Chronic Kidney Disease'],
          ),
        ),
        medicineLookupRepository: _FakeMedicineLookupRepository(
          result: _medicineLookupResult(
            warnings: const <String>[
              'Use caution in patients with renal impairment.',
            ],
          ),
        ),
        interactionLookupRepository: _FakeInteractionLookupRepository(),
      );

      final assessment = await service.assessMedicine(
        uid: 'user-1',
        medicine: const LocalMedicine(
          brandName: 'Nurofen',
          genericName: 'Ibuprofen',
        ),
      );

      expect(assessment.needsConfirmation, isTrue);
      expect(
        assessment.signals.single.type,
        MedicationSafetySignalType.chronicConditionWarning,
      );
      expect(
        assessment.signals.single.evidence,
        contains('Use caution in patients with renal impairment.'),
      );
    });
  });
}

UserProfileRecord _profile({
  List<String> allergyNames = const <String>[],
  List<String> medicalConditionNames = const <String>[],
}) {
  return UserProfileRecord(
    authUid: 'user-1',
    email: 'user@example.com',
    displayName: 'User',
    isPregnant: false,
    isBreastfeeding: false,
    allergyNames: allergyNames,
    medicalConditionNames: medicalConditionNames,
  );
}

MedicineLookupResult _medicineLookupResult({
  List<String> warnings = const <String>[],
  List<String> interactions = const <String>[],
}) {
  return MedicineLookupResult(
    query: 'Ibuprofen',
    searchMode: 'name',
    medicineName: 'Ibuprofen',
    brandNames: const <String>['Nurofen'],
    activeIngredients: const <String>['Ibuprofen'],
    usedFor: const <String>[],
    dose: const <String>[],
    warnings: warnings,
    sideEffects: const <String>[],
    interactions: interactions,
    alternatives: const <MedicineAlternativeItem>[],
    storage: const <String>[],
    disclaimer: const <String>[],
    source: 'test',
  );
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.profile)
    : super(firestore: FakeFirebaseFirestore());

  final UserProfileRecord? profile;

  @override
  Future<UserProfileRecord?> fetchProfile({required String uid}) async {
    return profile;
  }
}

class _FakeMedicineLookupRepository extends MedicineLookupRepository {
  _FakeMedicineLookupRepository({required this.result});

  final MedicineLookupResult result;

  @override
  Future<MedicineLookupResult> searchByName(String query) async {
    return result;
  }
}

class _FakeInteractionLookupRepository extends DrugInteractionLookupRepository {
  _FakeInteractionLookupRepository({this.result});

  final DrugInteractionLookupResult? result;
  final List<(String, String)> calls = <(String, String)>[];

  @override
  Future<DrugInteractionLookupResult> checkInteraction({
    required String firstDrugName,
    required String secondDrugName,
  }) async {
    calls.add((firstDrugName, secondDrugName));
    return result ??
        DrugInteractionLookupResult(
          firstQuery: firstDrugName,
          secondQuery: secondDrugName,
          firstDrug: firstDrugName,
          secondDrug: secondDrugName,
          severity: 'No specific interaction found',
          summary: 'No direct pair-specific interaction signal found.',
          source: 'test',
        );
  }
}
