import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';

void main() {
  group('DrugInteractionLookupRepository', () {
    test('calls the interaction endpoint and parses the response', () async {
      final repository = DrugInteractionLookupRepository(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/drug-interaction');
            expect(request.url.queryParameters['drug1'], 'warfarin');
            expect(request.url.queryParameters['drug2'], 'ibuprofen');

            return http.Response(
              jsonEncode({
                'first_query': 'warfarin',
                'second_query': 'ibuprofen',
                'first_drug': 'Warfarin',
                'second_drug': 'Ibuprofen',
                'first_generic_name': 'warfarin',
                'second_generic_name': 'ibuprofen',
                'severity': 'High',
                'summary': 'This combination can increase bleeding risk.',
                'mechanism':
                    'Concurrent anticoagulant and NSAID therapy can increase bleeding.',
                'warnings': ['Watch for unusual bleeding.'],
                'recommendations': [
                  'Review this combination with a clinician.',
                ],
                'evidence': ['Curated safety rule matched.'],
                'source': 'rxnorm+openfda+dailymed+heuristic',
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        medicineNameRepository: _FakeMedicineNameRepository(
          entries: const <MedicineNameEntry>[],
        ),
      );

      final result = await repository.checkInteraction(
        firstDrugName: ' warfarin ',
        secondDrugName: 'ibuprofen',
      );

      expect(result.firstDrug, 'Warfarin');
      expect(result.secondDrug, 'Ibuprofen');
      expect(result.severity, 'High');
      expect(result.warnings, ['Watch for unusual bleeding.']);
      expect(result.queryDrugIds, ['ibuprofen', 'warfarin']);
    });

    test('resolves local brand names before calling the API', () async {
      final repository = DrugInteractionLookupRepository(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/drug-interaction');
            expect(request.url.queryParameters['drug1'], 'Ibuprofen');
            expect(request.url.queryParameters['drug2'], 'Paracetamol');

            return http.Response(
              jsonEncode({
                'first_query': 'Ibuprofen',
                'second_query': 'Paracetamol',
                'first_drug': 'Ibuprofen',
                'second_drug': 'Acetaminophen',
                'first_generic_name': 'Ibuprofen',
                'second_generic_name': 'Acetaminophen',
                'severity': 'No specific interaction found',
                'summary': 'No direct pair-specific interaction signal found.',
                'warnings': ['Still check dose limits.'],
                'recommendations': ['Ask a pharmacist if unsure.'],
                'evidence': ['Public labels checked.'],
                'source': 'rxnorm+openfda+dailymed+heuristic',
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        medicineNameRepository: _FakeMedicineNameRepository(
          entries: const <MedicineNameEntry>[
            MedicineNameEntry(
              id: '1',
              brandName: 'Trofin',
              genericName: 'Ibuprofen',
            ),
            MedicineNameEntry(
              id: '2',
              brandName: 'Acamol',
              genericName: 'Paracetamol',
            ),
          ],
        ),
      );

      final result = await repository.checkInteraction(
        firstDrugName: ' trofin ',
        secondDrugName: 'Acamol',
      );

      expect(result.firstInputName, 'trofin');
      expect(result.secondInputName, 'Acamol');
      expect(result.firstLocalBrandName, 'Trofin');
      expect(result.firstLocalGenericName, 'Ibuprofen');
      expect(result.secondLocalBrandName, 'Acamol');
      expect(result.secondLocalGenericName, 'Paracetamol');
      expect(result.queryDrugIds, ['ibuprofen', 'paracetamol']);
    });

    test('rejects the same medicine entered twice', () async {
      final repository = DrugInteractionLookupRepository(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            fail('The API should not be called when validation fails.');
          }),
        ),
        medicineNameRepository: _FakeMedicineNameRepository(
          entries: const <MedicineNameEntry>[],
        ),
      );

      expect(
        () => repository.checkInteraction(
          firstDrugName: 'Ibuprofen',
          secondDrugName: 'ibuprofen',
        ),
        throwsA(
          isA<DrugInteractionLookupRepositoryException>().having(
            (error) => error.message,
            'message',
            'Please enter two different medicines.',
          ),
        ),
      );
    });
  });
}

class _FakeMedicineNameRepository extends MedicineNameRepository {
  _FakeMedicineNameRepository({required this.entries});

  final List<MedicineNameEntry> entries;

  @override
  Future<List<MedicineNameEntry>> loadEntries() async => entries;
}
