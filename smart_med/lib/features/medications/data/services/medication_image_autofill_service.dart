import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';
import 'package:smart_med/data/medicine/medicine_name_matcher.dart';
import 'package:smart_med/features/medicine_search/data/services/medicine_image_text_recognizer.dart';
import 'package:smart_med/models/local_medicine.dart';
import 'package:smart_med/services/local_medicine_service.dart';

class MedicationImageAutofillException implements Exception {
  const MedicationImageAutofillException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MedicationImageAutofillResult {
  const MedicationImageAutofillResult({required this.medicine, this.dosage});

  final LocalMedicine medicine;
  final MedicationImageDosage? dosage;
}

class MedicationImageDosage {
  const MedicationImageDosage({required this.amount, required this.unit});

  final double amount;
  final String unit;

  String get formattedAmount {
    final hasNoFraction = amount == amount.truncateToDouble();
    return hasNoFraction ? amount.toStringAsFixed(0) : amount.toString();
  }
}

class MedicationImageTextReadResult {
  const MedicationImageTextReadResult({
    required this.rawText,
    required this.candidates,
  });

  final String rawText;
  final List<String> candidates;
}

abstract class MedicationImageTextReader {
  Future<MedicationImageTextReadResult> read({required XFile image});
}

class MlKitMedicationImageTextReader implements MedicationImageTextReader {
  const MlKitMedicationImageTextReader();

  @override
  Future<MedicationImageTextReadResult> read({required XFile image}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const MedicationImageAutofillException(
        'Photo autofill is currently supported on Android and iPhone only.',
      );
    }

    final imagePath = image.path.trim();
    if (imagePath.isEmpty) {
      throw const MedicationImageAutofillException(
        'The selected image could not be read.',
      );
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.trim();
      final candidates = MedicineImageTextParser.buildCandidates(
        recognizedText,
      );

      if (candidates.isEmpty) {
        throw const MedicationImageAutofillException(
          'No medicine name could be read from the image. Try a clearer photo with the label visible.',
        );
      }

      return MedicationImageTextReadResult(
        rawText: rawText,
        candidates: candidates,
      );
    } catch (error) {
      if (error is MedicationImageAutofillException) {
        rethrow;
      }

      throw const MedicationImageAutofillException(
        'Photo autofill could not read this image. Try another photo with the medicine name clearly visible.',
      );
    } finally {
      await textRecognizer.close();
    }
  }
}

class MedicationImageAutofillService {
  MedicationImageAutofillService({
    LocalMedicineService? medicineService,
    MedicationImageTextReader? imageReader,
    MedicineNameMatcher? medicineNameMatcher,
  }) : _localMedicineService = medicineService ?? localMedicineService,
       _imageTextReader = imageReader ?? medicationImageTextReader,
       _medicineNameMatcher =
           medicineNameMatcher ?? const MedicineNameMatcher();

  static const String _noLocalMatchMessage =
      'No matching medicine name was found in the local medicine list for this photo. You can still enter the details manually.';

  final LocalMedicineService _localMedicineService;
  final MedicationImageTextReader _imageTextReader;
  final MedicineNameMatcher _medicineNameMatcher;

  Future<MedicationImageAutofillResult> identifyLocalMedicine({
    required XFile image,
  }) async {
    final readResult = await _imageTextReader.read(image: image);
    final medicines = await _localMedicineService.loadMedicines();
    final entryMap = _buildEntryMap(medicines);

    final match = _medicineNameMatcher.match(
      ocrCandidates: readResult.candidates,
      entries: entryMap.keys.toList(growable: false),
    );
    if (match == null) {
      throw const MedicationImageAutofillException(_noLocalMatchMessage);
    }

    final matchedMedicine = entryMap[match.entry];
    if (matchedMedicine == null) {
      throw const MedicationImageAutofillException(_noLocalMatchMessage);
    }

    final resolvedMedicine = _resolveMatchedMedicine(
      match: match,
      matchedMedicine: matchedMedicine,
    );

    final dosage =
        _extractDosage(readResult.rawText) ??
        _extractDosage(resolvedMedicine.strength);

    return MedicationImageAutofillResult(
      medicine: resolvedMedicine,
      dosage: dosage,
    );
  }

  Map<MedicineNameEntry, LocalMedicine> _buildEntryMap(
    List<LocalMedicine> medicines,
  ) {
    final entries = <MedicineNameEntry, LocalMedicine>{};

    for (final medicine in medicines) {
      final brandName = _cleanText(medicine.brandName) ?? '';
      final genericName = _cleanText(medicine.genericName) ?? '';
      if (brandName.isEmpty && genericName.isEmpty) {
        continue;
      }

      final entry = MedicineNameEntry(
        id: _cleanText(medicine.id),
        brandName: brandName,
        genericName: genericName,
      );
      entries[entry] = medicine;
    }

    return entries;
  }

  LocalMedicine _resolveMatchedMedicine({
    required MedicineNameMatch match,
    required LocalMedicine matchedMedicine,
  }) {
    if (match.matchedOnBrand) {
      return matchedMedicine;
    }

    final genericName = _cleanText(match.matchedGenericName);
    if (genericName == null) {
      return matchedMedicine;
    }

    return LocalMedicine(
      genericName: genericName,
      activeIngredients: matchedMedicine.activeIngredients,
      strength: matchedMedicine.strength,
      form: matchedMedicine.form,
      category: matchedMedicine.category,
      searchNames: <String>[...matchedMedicine.searchNames, genericName],
    );
  }

  MedicationImageDosage? _extractDosage(String? sourceText) {
    final text = sourceText?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'\b(\d+(?:[.,]\d+)?)\s?(mg|mcg|g|ml|iu)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    final amount = double.tryParse((match.group(1) ?? '').replaceAll(',', '.'));
    final unit = match.group(2)?.trim().toLowerCase();
    if (amount == null || amount <= 0 || unit == null || unit.isEmpty) {
      return null;
    }

    return MedicationImageDosage(amount: amount, unit: unit);
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

const MedicationImageTextReader medicationImageTextReader =
    MlKitMedicationImageTextReader();

final MedicationImageAutofillService medicationImageAutofillService =
    MedicationImageAutofillService();
