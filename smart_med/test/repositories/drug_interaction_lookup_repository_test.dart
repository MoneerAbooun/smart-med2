import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_med/core/network/api_client.dart';
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

    test('rejects the same medicine entered twice', () async {
      final repository = DrugInteractionLookupRepository(
        apiClient: ApiClient(
          httpClient: MockClient((request) async {
            fail('The API should not be called when validation fails.');
          }),
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
