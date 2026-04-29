import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/features/medications/data/services/medication_image_autofill_service.dart';
import 'package:smart_med/services/local_medicine_service.dart';

void main() {
  group('MedicationImageAutofillService', () {
    test(
      'matches a local medicine and extracts the dose from OCR text',
      () async {
        final service = MedicationImageAutofillService(
          medicineService: LocalMedicineService(
            bundle: _FakeAssetBundle(<String, String>{
              'assets/data/local_medicines.json':
                  '[{"id":"1","brandName":"Nurofen","genericName":"Ibuprofen"}]',
            }),
          ),
          imageReader: const _FakeMedicationImageTextReader(
            rawText: 'Nurofen 400mg Tablets',
            candidates: <String>['Nurofen'],
          ),
        );

        final result = await service.identifyLocalMedicine(image: _testImage());

        expect(result.medicine.brandName, 'Nurofen');
        expect(result.medicine.genericName, 'Ibuprofen');
        expect(result.dosage?.amount, 400);
        expect(result.dosage?.unit, 'mg');
      },
    );

    test('falls back to the local strength when OCR text has no dose', () async {
      final service = MedicationImageAutofillService(
        medicineService: LocalMedicineService(
          bundle: _FakeAssetBundle(<String, String>{
            'assets/data/local_medicines.json':
                '[{"id":"1","brandName":"Augmentin","genericName":"Amoxicillin + Clavulanic Acid","strength":"250 mg"}]',
          }),
        ),
        imageReader: const _FakeMedicationImageTextReader(
          rawText: 'Augmentin tablets',
          candidates: <String>['Augmentin'],
        ),
      );

      final result = await service.identifyLocalMedicine(image: _testImage());

      expect(result.medicine.brandName, 'Augmentin');
      expect(result.dosage?.amount, 250);
      expect(result.dosage?.unit, 'mg');
    });

    test('uses the generic name when the photo only matches a generic', () async {
      final service = MedicationImageAutofillService(
        medicineService: LocalMedicineService(
          bundle: _FakeAssetBundle(<String, String>{
            'assets/data/local_medicines.json':
                '[{"id":"1","brandName":"Nurofen","genericName":"Ibuprofen"},{"id":"2","brandName":"Brufen","genericName":"Ibuprofen"}]',
          }),
        ),
        imageReader: const _FakeMedicationImageTextReader(
          rawText: 'Ibuprofen 400mg Tablets',
          candidates: <String>['Ibuprofen'],
        ),
      );

      final result = await service.identifyLocalMedicine(image: _testImage());

      expect(result.medicine.brandName, isNull);
      expect(result.medicine.genericName, 'Ibuprofen');
      expect(result.dosage?.amount, 400);
      expect(result.dosage?.unit, 'mg');
    });

    test('throws a helpful message when no local medicine matches', () async {
      final service = MedicationImageAutofillService(
        medicineService: LocalMedicineService(
          bundle: _FakeAssetBundle(<String, String>{
            'assets/data/local_medicines.json':
                '[{"id":"1","brandName":"Nurofen","genericName":"Ibuprofen"}]',
          }),
        ),
        imageReader: const _FakeMedicationImageTextReader(
          rawText: 'Unknown 400mg',
          candidates: <String>['Unknown'],
        ),
      );

      expect(
        () => service.identifyLocalMedicine(image: _testImage()),
        throwsA(
          isA<MedicationImageAutofillException>().having(
            (error) => error.message,
            'message',
            'No matching medicine name was found in the local medicine list for this photo. You can still enter the details manually.',
          ),
        ),
      );
    });
  });
}

XFile _testImage() {
  return XFile.fromData(
    Uint8List.fromList(<int>[1, 2, 3]),
    name: 'pill.png',
    mimeType: 'image/png',
  );
}

class _FakeMedicationImageTextReader implements MedicationImageTextReader {
  const _FakeMedicationImageTextReader({
    required this.rawText,
    required this.candidates,
  });

  final String rawText;
  final List<String> candidates;

  @override
  Future<MedicationImageTextReadResult> read({required XFile image}) async {
    return MedicationImageTextReadResult(
      rawText: rawText,
      candidates: candidates,
    );
  }
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing asset: $key');
    }

    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing asset: $key');
    }

    return value;
  }
}
