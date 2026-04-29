import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/data/medicine/medicine_name_matcher.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/medicine_search/data/services/medicine_image_text_recognizer.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart'
    as local_medicine;

class MedicineLookupRepositoryException implements Exception {
  const MedicineLookupRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MedicineLookupRepository {
  MedicineLookupRepository({
    ApiClient? apiClient,
    MedicineImageTextRecognizer? imageTextRecognizer,
    local_medicine.MedicineNameRepository? medicineNameRepository,
    MedicineNameMatcher? medicineNameMatcher,
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageTextRecognizer =
           imageTextRecognizer ?? medicineImageTextRecognizer,
       _medicineNameRepository =
           medicineNameRepository ?? local_medicine.medicineNameRepository,
       _medicineNameMatcher =
           medicineNameMatcher ?? const MedicineNameMatcher();

  static const String _noBackendMatchMessage =
      'No matching medicine was found. Try a brand name or generic name.';
  static const String _noLocalMatchMessage =
      'No matching medicine name was found in the local medicine list for the text in this image. Try a clearer photo with the medicine name visible.';

  final ApiClient _apiClient;
  final MedicineImageTextRecognizer _imageTextRecognizer;
  final local_medicine.MedicineNameRepository _medicineNameRepository;
  final MedicineNameMatcher _medicineNameMatcher;

  Future<MedicineLookupResult> searchByName(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const MedicineLookupRepositoryException(
        'Please enter a medicine name.',
      );
    }

    final localMatch = await _tryMatchLocalMedicineName(normalizedQuery);
    debugPrint(
      'Medicine name matched brand name: ${localMatch?.matchedBrandName ?? 'none'}',
    );
    debugPrint(
      'Medicine name matched generic name: ${localMatch?.matchedGenericName ?? 'none'}',
    );

    final resolution = await _searchUsingBackendQueries(
      queries: localMatch?.backendQueries ?? <String>[normalizedQuery],
      onQuery: (candidate) {
        debugPrint('Medicine name final query sent to backend: $candidate');
      },
    );

    return resolution.result.copyWith(
      query: normalizedQuery,
      searchMode: 'name',
      matchedName: resolution.result.matchedName ?? localMatch?.preferredQuery,
      genericName:
          resolution.result.genericName ?? localMatch?.matchedGenericName,
    );
  }

  Future<MedicineLookupResult> searchByImage({required XFile image}) async {
    try {
      final candidates = await _imageTextRecognizer.extractCandidates(
        image: image,
      );
      debugPrint('Medicine image OCR candidates: $candidates');

      final entries = await _medicineNameRepository.loadEntries();
      final match = _medicineNameMatcher.match(
        ocrCandidates: candidates,
        entries: entries,
      );
      final cleanedText =
          match?.cleanedText ??
          _medicineNameMatcher.normalizeCombinedText(candidates);
      debugPrint('Medicine image cleaned OCR text: $cleanedText');

      if (match == null) {
        debugPrint('Medicine image matched brand name: none');
        debugPrint('Medicine image matched generic name: none');
        throw const MedicineLookupRepositoryException(_noLocalMatchMessage);
      }

      debugPrint(
        'Medicine image matched brand name: ${match.matchedBrandName ?? 'none'}',
      );
      debugPrint(
        'Medicine image matched generic name: ${match.matchedGenericName ?? 'none'}',
      );

      final resolution = await _searchUsingBackendQueries(
        queries: match.backendQueries,
        onQuery: (candidate) {
          debugPrint('Medicine image final query sent to backend: $candidate');
        },
      );

      return resolution.result.copyWith(
        query: resolution.usedQuery,
        searchMode: 'image',
        identificationReason:
            'Identified from OCR text by matching the local medicine list.',
        matchedName: resolution.result.matchedName ?? match.preferredQuery,
        genericName: resolution.result.genericName ?? match.matchedGenericName,
      );
    } on local_medicine.MedicineNameRepositoryException catch (error) {
      throw MedicineLookupRepositoryException(error.message);
    } on MedicineImageTextRecognizerException catch (error) {
      throw MedicineLookupRepositoryException(error.message);
    } catch (error) {
      throw MedicineLookupRepositoryException(error.toString());
    }
  }

  Future<_BackendQueryResolution> _searchUsingBackendQueries({
    required List<String> queries,
    required void Function(String query) onQuery,
  }) async {
    MedicineLookupRepositoryException? firstLookupError;

    for (final candidate in queries) {
      onQuery(candidate);

      try {
        final response = await _apiClient.getJson(
          path: '/medicine-information',
          queryParameters: <String, String>{'name': candidate},
        );
        return _BackendQueryResolution(
          result: MedicineLookupResult.fromMap(response),
          usedQuery: candidate,
        );
      } on ApiClientException catch (error) {
        final friendlyMessage = _friendlyNameSearchErrorMessage(error);
        if (friendlyMessage == _noBackendMatchMessage) {
          firstLookupError ??= MedicineLookupRepositoryException(
            friendlyMessage,
          );
          continue;
        }

        throw MedicineLookupRepositoryException(friendlyMessage);
      } catch (error) {
        throw MedicineLookupRepositoryException(error.toString());
      }
    }

    throw firstLookupError ??
        const MedicineLookupRepositoryException(_noBackendMatchMessage);
  }

  Future<MedicineNameMatch?> _tryMatchLocalMedicineName(String query) async {
    try {
      final entries = await _medicineNameRepository.loadEntries();
      return _medicineNameMatcher.match(
        ocrCandidates: <String>[query],
        entries: entries,
      );
    } on local_medicine.MedicineNameRepositoryException catch (error) {
      debugPrint(
        'Medicine name local medicine list unavailable: ${error.message}',
      );
      return null;
    }
  }

  String _friendlyNameSearchErrorMessage(ApiClientException error) {
    if (error.statusCode == 404) {
      return _noBackendMatchMessage;
    }

    return error.message;
  }
}

final MedicineLookupRepository medicineLookupRepository =
    MedicineLookupRepository();

class _BackendQueryResolution {
  const _BackendQueryResolution({
    required this.result,
    required this.usedQuery,
  });

  final MedicineLookupResult result;
  final String usedQuery;
}
