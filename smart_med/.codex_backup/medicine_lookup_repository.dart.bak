import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/medicine_search/data/services/medicine_image_text_recognizer.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

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
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageTextRecognizer = imageTextRecognizer ?? medicineImageTextRecognizer;

  final ApiClient _apiClient;
  final MedicineImageTextRecognizer _imageTextRecognizer;

  Future<MedicineLookupResult> searchByName(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const MedicineLookupRepositoryException(
        'Please enter a medicine name.',
      );
    }

    try {
      final response = await _apiClient.getJson(
        path: '/medicine-information',
        queryParameters: <String, String>{'name': normalizedQuery},
      );
      return MedicineLookupResult.fromMap(response);
    } on ApiClientException catch (error) {
      throw MedicineLookupRepositoryException(
        _friendlyNameSearchErrorMessage(error),
      );
    } catch (error) {
      throw MedicineLookupRepositoryException(error.toString());
    }
  }

  Future<MedicineLookupResult> searchByImage({required XFile image}) async {
    try {
      final candidates = await _imageTextRecognizer.extractCandidates(
        image: image,
      );

      MedicineLookupRepositoryException? firstLookupError;

      for (final candidate in candidates) {
        try {
          final result = await searchByName(candidate);
          return result.copyWith(
            query: candidate,
            searchMode: 'image',
            identificationReason:
                'Identified from text visible in the image.',
          );
        } on MedicineLookupRepositoryException catch (error) {
          if (error.message ==
              'No matching medicine was found. Try a brand name or generic name.') {
            firstLookupError ??= error;
            continue;
          }

          rethrow;
        }
      }

      throw firstLookupError ??
          const MedicineLookupRepositoryException(
            'No matching medicine was found in the image. Try a clearer photo with the medicine name visible.',
          );
    } on MedicineImageTextRecognizerException catch (error) {
      throw MedicineLookupRepositoryException(error.message);
    } catch (error) {
      throw MedicineLookupRepositoryException(error.toString());
    }
  }

  String _friendlyNameSearchErrorMessage(ApiClientException error) {
    if (error.statusCode == 404) {
      return 'No matching medicine was found. Try a brand name or generic name.';
    }

    return error.message;
  }
}

final MedicineLookupRepository medicineLookupRepository =
    MedicineLookupRepository();
