import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class MedicineImageTextRecognizerException implements Exception {
  const MedicineImageTextRecognizerException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MedicineImageTextRecognizer {
  Future<List<String>> extractCandidates({required XFile image});
}

class MedicineImageTextParser {
  const MedicineImageTextParser._();

  static const Set<String> _stopWords = <String>{
    'active',
    'adult',
    'adults',
    'caplet',
    'caplets',
    'capsule',
    'capsules',
    'chewable',
    'children',
    'coated',
    'directions',
    'drug',
    'easy',
    'effective',
    'extra',
    'fever',
    'film',
    'gel',
    'gelcap',
    'gelcaps',
    'gels',
    'ingredient',
    'ingredients',
    'keep',
    'liquid',
    'medication',
    'medicine',
    'oral',
    'package',
    'packages',
    'pain',
    'pharmacy',
    'reduce',
    'reducer',
    'relief',
    'reliever',
    'release',
    'room',
    'softgel',
    'softgels',
    'store',
    'strength',
    'suspension',
    'swallow',
    'syrup',
    'tablet',
    'tablets',
    'temperature',
    'use',
    'uses',
    'warning',
    'warnings',
  };

  static List<String> buildCandidates(RecognizedText recognizedText) {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String value) {
      final cleanedValue = value.trim();
      if (cleanedValue.isEmpty) {
        return;
      }

      final key = cleanedValue.toLowerCase();
      if (seen.add(key)) {
        candidates.add(cleanedValue);
      }
    }

    final segments = <String>[
      for (final block in recognizedText.blocks) block.text,
      for (final block in recognizedText.blocks)
        for (final line in block.lines) line.text,
    ];

    if (segments.isEmpty && recognizedText.text.trim().isNotEmpty) {
      segments.add(recognizedText.text);
    }

    for (final segment in segments) {
      for (final candidate in candidatesFromSegment(segment)) {
        addCandidate(candidate);
      }
    }

    return candidates;
  }

  static List<String> candidatesFromSegment(String segment) {
    final collapsedWhitespace = segment
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (collapsedWhitespace.isEmpty) {
      return const <String>[];
    }

    final noDosage = collapsedWhitespace.replaceAll(
      RegExp(
        r'\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|g|kg|ml|iu|%)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    final alphanumericOnly = noDosage
        .replaceAll(RegExp(r'[^A-Za-z0-9\-\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (alphanumericOnly.isEmpty) {
      return const <String>[];
    }

    final tokens = alphanumericOnly
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);

    final filteredTokens = tokens.where(isUsefulToken).toList(growable: false);
    final candidates = <String>[];
    final seen = <String>{};

    void add(String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) {
        return;
      }

      final key = cleaned.toLowerCase();
      if (seen.add(key)) {
        candidates.add(cleaned);
      }
    }

    add(alphanumericOnly);

    if (filteredTokens.isNotEmpty) {
      add(filteredTokens.join(' '));

      for (var length = 1; length <= 3; length++) {
        if (filteredTokens.length < length) {
          break;
        }

        for (var start = 0; start <= filteredTokens.length - length; start++) {
          add(filteredTokens.sublist(start, start + length).join(' '));
        }
      }
    }

    return candidates;
  }

  static bool isUsefulToken(String token) {
    final normalized = token.trim().toLowerCase();
    if (normalized.length < 3) {
      return false;
    }

    if (RegExp(r'\d').hasMatch(normalized)) {
      return false;
    }

    return !_stopWords.contains(normalized);
  }
}

class MlKitMedicineImageTextRecognizer implements MedicineImageTextRecognizer {
  const MlKitMedicineImageTextRecognizer();

  @override
  Future<List<String>> extractCandidates({required XFile image}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const MedicineImageTextRecognizerException(
        'Image search from photos is currently supported on Android and iPhone only.',
      );
    }

    final imagePath = image.path.trim();
    if (imagePath.isEmpty) {
      throw const MedicineImageTextRecognizerException(
        'The selected image could not be read.',
      );
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      debugPrint('Medicine image OCR raw text: ${recognizedText.text}');
      final candidates = MedicineImageTextParser.buildCandidates(
        recognizedText,
      );
      debugPrint('Medicine image OCR candidates: $candidates');

      if (candidates.isEmpty) {
        throw const MedicineImageTextRecognizerException(
          'No medicine name could be read from the image. Try a clearer photo with the label or pill markings visible.',
        );
      }

      return candidates;
    } catch (error) {
      if (error is MedicineImageTextRecognizerException) {
        rethrow;
      }

      throw const MedicineImageTextRecognizerException(
        'Image search could not read text from the photo. Try another image with the medicine name clearly visible.',
      );
    } finally {
      await textRecognizer.close();
    }
  }
}

const MedicineImageTextRecognizer medicineImageTextRecognizer =
    MlKitMedicineImageTextRecognizer();
