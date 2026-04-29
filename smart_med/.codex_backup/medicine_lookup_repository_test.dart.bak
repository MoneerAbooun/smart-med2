import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/medicine_search/data/services/medicine_image_text_recognizer.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';

void main() {
  group('MedicineLookupRepository', () {
    test('calls the medicine information endpoint for name search', () async {
      final apiClient = _FakeApiClient(
        getJsonHandler:
            ({
              required String path,
              required Map<String, String> queryParameters,
              required Map<String, String> headers,
            }) async {
              expect(path, '/medicine-information');
              expect(queryParameters['name'], 'ibuprofen');

              return <String, dynamic>{
                'query': 'ibuprofen',
                'search_mode': 'name',
                'medicine_name': 'Ibuprofen',
                'generic_name': 'ibuprofen',
                'used_for': ['Pain relief'],
                'dose': ['200 mg every 4 to 6 hours'],
                'warnings': ['Avoid if allergic to NSAIDs.'],
                'side_effects': ['Upset stomach'],
                'interactions': ['May interact with blood thinners'],
                'alternatives': [
                  <String, dynamic>{'name': 'Advil', 'category': 'Brand name'},
                ],
                'storage': ['Store at room temperature'],
                'disclaimer': ['Talk to a clinician for personal advice.'],
                'brand_names': ['Advil'],
                'active_ingredients': ['Ibuprofen'],
                'source': 'rxnorm+dailymed+openfda',
              };
            },
      );

      final repository = MedicineLookupRepository(apiClient: apiClient);
      final result = await repository.searchByName(' ibuprofen ');

      expect(result.medicineName, 'Ibuprofen');
      expect(result.genericName, 'ibuprofen');
      expect(result.alternatives.first.displayLabel, 'Advil (Brand name)');
    });

    test('searches by image using OCR candidates and then name lookup', () async {
        final apiClient = _FakeApiClient(
          getJsonHandler:
              ({
                required String path,
                required Map<String, String> queryParameters,
                required Map<String, String> headers,
              }) async {
                expect(path, '/medicine-information');
                expect(queryParameters['name'], 'Advil');

                return <String, dynamic>{
                  'query': 'Advil',
                  'search_mode': 'name',
                  'medicine_name': 'Advil',
                  'generic_name': 'ibuprofen',
                  'used_for': ['Pain relief'],
                  'dose': ['Use as directed on the label'],
                  'warnings': ['Use carefully with stomach ulcers.'],
                  'side_effects': ['Nausea'],
                  'interactions': ['May interact with anticoagulants'],
                  'alternatives': const <Map<String, dynamic>>[],
                  'storage': ['Keep tightly closed'],
                  'disclaimer': ['This is not personal medical advice.'],
                  'brand_names': ['Advil'],
                  'active_ingredients': ['Ibuprofen'],
                  'source': 'rxnorm+dailymed+openfda',
                };
              },
        );

        final repository = MedicineLookupRepository(
          apiClient: apiClient,
          imageTextRecognizer: const _FakeImageTextRecognizer(
            candidates: <String>['Advil'],
          ),
        );
        final image = XFile.fromData(
          Uint8List.fromList(<int>[1, 2, 3]),
          name: 'pill.png',
          mimeType: 'image/png',
        );
        final result = await repository.searchByImage(image: image);

        expect(result.isImageSearch, isTrue);
        expect(
          result.identificationReason,
          'Identified from text visible in the image.',
        );
      },
    );

    test('rejects an empty name search before calling the API', () async {
      final repository = MedicineLookupRepository(apiClient: _FakeApiClient());

      expect(
        () => repository.searchByName('   '),
        throwsA(
          isA<MedicineLookupRepositoryException>().having(
            (error) => error.message,
            'message',
            'Please enter a medicine name.',
          ),
        ),
      );
    });

    test('surfaces OCR failure when no medicine text can be read', () async {
      final repository = MedicineLookupRepository(
        apiClient: _FakeApiClient(
        ),
        imageTextRecognizer: const _FakeImageTextRecognizer(
          error: MedicineImageTextRecognizerException(
            'No medicine name could be read from the image. Try a clearer photo with the label or pill markings visible.',
          ),
        ),
      );

      final image = XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3]),
        name: 'pill.png',
        mimeType: 'image/png',
      );

      expect(
        () => repository.searchByImage(image: image),
        throwsA(
          isA<MedicineLookupRepositoryException>().having(
            (error) => error.message,
            'message',
            'No medicine name could be read from the image. Try a clearer photo with the label or pill markings visible.',
          ),
        ),
      );
    });
  });
}

typedef _GetJsonHandler =
    Future<Map<String, dynamic>> Function({
      required String path,
      required Map<String, String> queryParameters,
      required Map<String, String> headers,
    });

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.getJsonHandler});

  final _GetJsonHandler? getJsonHandler;

  @override
  Future<Map<String, dynamic>> getJson({
    required String path,
    Map<String, String> queryParameters = const <String, String>{},
    Map<String, String> headers = const <String, String>{},
  }) async {
    final handler = getJsonHandler;
    if (handler == null) {
      throw UnimplementedError('getJson was not expected in this test.');
    }

    return handler(
      path: path,
      queryParameters: queryParameters,
      headers: headers,
    );
  }
}

class _FakeImageTextRecognizer implements MedicineImageTextRecognizer {
  const _FakeImageTextRecognizer({
    this.candidates = const <String>[],
    this.error,
  });

  final List<String> candidates;
  final MedicineImageTextRecognizerException? error;

  @override
  Future<List<String>> extractCandidates({required XFile image}) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }

    return candidates;
  }
}
