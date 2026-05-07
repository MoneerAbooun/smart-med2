import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/data/medicine/medicine_name_matcher.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart'
    as local_medicine;
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';

class DrugInteractionLookupRepositoryException implements Exception {
  const DrugInteractionLookupRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DrugInteractionLookupRepository {
  DrugInteractionLookupRepository({
    ApiClient? apiClient,
    local_medicine.MedicineNameRepository? medicineNameRepository,
    MedicineNameMatcher? medicineNameMatcher,
  }) : _apiClient = apiClient ?? ApiClient(),
       _medicineNameRepository =
           medicineNameRepository ?? local_medicine.medicineNameRepository,
       _medicineNameMatcher =
           medicineNameMatcher ?? const MedicineNameMatcher();

  final ApiClient _apiClient;
  final local_medicine.MedicineNameRepository _medicineNameRepository;
  final MedicineNameMatcher _medicineNameMatcher;

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

    final firstResolution = await _resolveLocalMedicineName(normalizedFirst);
    final secondResolution = await _resolveLocalMedicineName(normalizedSecond);

    try {
      final result = await _checkUsingResolvedQueries(
        firstResolution: firstResolution,
        secondResolution: secondResolution,
      );

      return result.copyWith(
        firstInputName: firstResolution.inputName,
        secondInputName: secondResolution.inputName,
        firstLocalBrandName: firstResolution.localBrandName,
        firstLocalGenericName: firstResolution.localGenericName,
        secondLocalBrandName: secondResolution.localBrandName,
        secondLocalGenericName: secondResolution.localGenericName,
      );
    } on DrugInteractionLookupRepositoryException {
      rethrow;
    } catch (error) {
      throw DrugInteractionLookupRepositoryException(error.toString());
    }
  }

  Future<DrugInteractionLookupResult> _checkUsingResolvedQueries({
    required _InteractionMedicineResolution firstResolution,
    required _InteractionMedicineResolution secondResolution,
  }) async {
    DrugInteractionLookupRepositoryException? firstRecoverableError;

    for (final firstQuery in firstResolution.backendQueries) {
      for (final secondQuery in secondResolution.backendQueries) {
        if (firstQuery.toLowerCase() == secondQuery.toLowerCase()) {
          continue;
        }

        try {
          final response = await _apiClient.getJson(
            path: '/drug-interaction',
            queryParameters: <String, String>{
              'drug1': firstQuery,
              'drug2': secondQuery,
            },
          );
          return DrugInteractionLookupResult.fromMap(response);
        } on ApiClientException catch (error) {
          final repositoryError = DrugInteractionLookupRepositoryException(
            error.message,
          );
          if (_shouldTryNextBackendQuery(error)) {
            firstRecoverableError ??= repositoryError;
            continue;
          }

          throw repositoryError;
        }
      }
    }

    throw firstRecoverableError ??
        const DrugInteractionLookupRepositoryException(
          'Please enter two different medicines.',
        );
  }

  Future<_InteractionMedicineResolution> _resolveLocalMedicineName(
    String inputName,
  ) async {
    try {
      final entries = await _medicineNameRepository.loadEntries();
      final match = _medicineNameMatcher.match(
        ocrCandidates: <String>[inputName],
        entries: entries,
      );

      if (match == null) {
        return _InteractionMedicineResolution.unmatched(inputName);
      }

      return _InteractionMedicineResolution(
        inputName: inputName,
        backendQueries: _buildBackendQueries(inputName, match),
        localBrandName: match.matchedBrandName,
        localGenericName: match.matchedGenericName,
      );
    } on local_medicine.MedicineNameRepositoryException {
      return _InteractionMedicineResolution.unmatched(inputName);
    }
  }

  List<String> _buildBackendQueries(String inputName, MedicineNameMatch match) {
    final queries = <String>[];
    final seen = <String>{};

    void addQuery(String? value) {
      final query = value?.trim();
      if (query == null || query.isEmpty) {
        return;
      }

      if (seen.add(query.toLowerCase())) {
        queries.add(query);
      }
    }

    addQuery(match.matchedGenericName);
    addQuery(match.matchedBrandName);
    addQuery(match.preferredQuery);
    addQuery(inputName);

    return List<String>.unmodifiable(queries);
  }

  bool _shouldTryNextBackendQuery(ApiClientException error) {
    if (error.statusCode == 404) {
      return true;
    }

    return error.statusCode == 400 &&
        error.message.toLowerCase().contains('different medicines');
  }
}

final DrugInteractionLookupRepository drugInteractionLookupRepository =
    DrugInteractionLookupRepository();

class _InteractionMedicineResolution {
  const _InteractionMedicineResolution({
    required this.inputName,
    required this.backendQueries,
    this.localBrandName,
    this.localGenericName,
  });

  factory _InteractionMedicineResolution.unmatched(String inputName) {
    return _InteractionMedicineResolution(
      inputName: inputName,
      backendQueries: <String>[inputName],
    );
  }

  final String inputName;
  final List<String> backendQueries;
  final String? localBrandName;
  final String? localGenericName;
}
