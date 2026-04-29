import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';

class DrugInteractionLookupRepositoryException implements Exception {
  const DrugInteractionLookupRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DrugInteractionLookupRepository {
  DrugInteractionLookupRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<DrugInteractionLookupResult> checkInteraction({
    required String firstDrugName,
    required String secondDrugName,
  }) async {
    final normalizedFirst = firstDrugName.trim();
    final normalizedSecond = secondDrugName.trim();

    if (normalizedFirst.isEmpty || normalizedSecond.isEmpty) {
      throw const DrugInteractionLookupRepositoryException(
        'Please enter both medicine names.',
      );
    }

    if (normalizedFirst.toLowerCase() == normalizedSecond.toLowerCase()) {
      throw const DrugInteractionLookupRepositoryException(
        'Please enter two different medicines.',
      );
    }

    try {
      final response = await _apiClient.getJson(
        path: '/drug-interaction',
        queryParameters: <String, String>{
          'drug1': normalizedFirst,
          'drug2': normalizedSecond,
        },
      );
      return DrugInteractionLookupResult.fromMap(response);
    } on DrugInteractionLookupRepositoryException {
      rethrow;
    } on ApiClientException catch (error) {
      throw DrugInteractionLookupRepositoryException(error.message);
    } catch (error) {
      throw DrugInteractionLookupRepositoryException(error.toString());
    }
  }
}

final DrugInteractionLookupRepository drugInteractionLookupRepository =
    DrugInteractionLookupRepository();
