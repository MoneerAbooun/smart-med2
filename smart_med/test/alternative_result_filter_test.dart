import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/features/alternative_drug/alternative_result_filter.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

void main() {
  group('removeSameMedicineAlternatives', () {
    test('removes generic dose products but keeps distinct brand products', () {
      final result = _buildResult(
        alternatives: const <MedicineAlternativeItem>[
          MedicineAlternativeItem(
            name: 'warfarin sodium 3 MG Oral Tablet',
            category: 'Generic drug',
            termType: 'SCD',
          ),
          MedicineAlternativeItem(
            name: 'Coumadin 1 MG Oral Tablet',
            category: 'Brand drug',
            termType: 'SBD',
          ),
          MedicineAlternativeItem(
            name: 'Jantoven 1 MG Oral Tablet',
            category: 'Brand drug',
            termType: 'SBD',
          ),
          MedicineAlternativeItem(
            name: 'Apixaban 5 MG Oral Tablet',
            category: 'Therapeutic alternative',
            termType: 'THERAPEUTIC',
          ),
        ],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives.map((item) => item.name), [
        'Coumadin 1 MG Oral Tablet',
        'Jantoven 1 MG Oral Tablet',
        'Apixaban 5 MG Oral Tablet',
      ]);
    });

    test('removes dose variants even when the backend omits a term type', () {
      final result = _buildResult(
        alternatives: const <MedicineAlternativeItem>[
          MedicineAlternativeItem(
            name: 'warfarin sodium 4 MG Oral Tablet',
            category: 'Alternative',
          ),
          MedicineAlternativeItem(
            name: 'Heparin injection',
            category: 'Alternative',
          ),
        ],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives.map((item) => item.name), [
        'Heparin injection',
      ]);
    });

    test('adds the generic and keeps other brands for a searched brand', () {
      final result = _buildResult(
        query: 'Coumadin',
        medicineName: 'Coumadin',
        genericName: 'warfarin',
        brandNames: const <String>['Coumadin', 'Jantoven'],
        alternatives: const <MedicineAlternativeItem>[
          MedicineAlternativeItem(
            name: 'Coumadin 1 MG Oral Tablet',
            category: 'Brand drug',
            termType: 'SBD',
          ),
          MedicineAlternativeItem(
            name: 'Jantoven 1 MG Oral Tablet',
            category: 'Brand drug',
            termType: 'SBD',
          ),
        ],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives.map((item) => item.name), [
        'warfarin',
        'Jantoven 1 MG Oral Tablet',
      ]);
    });

    test('adds the generic name when searching by a matched brand name', () {
      final result = _buildResult(
        query: 'Nurofen',
        medicineName: 'Nurofen',
        genericName: 'Ibuprofen',
        brandNames: const <String>['Nurofen'],
        activeIngredients: const <String>['Ibuprofen'],
        alternatives: const <MedicineAlternativeItem>[
          MedicineAlternativeItem(
            name: 'Nurofen 200 MG Oral Tablet',
            category: 'Brand drug',
            termType: 'SBD',
          ),
        ],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives, hasLength(1));
      expect(filtered.alternatives.single.name, 'Ibuprofen');
      expect(filtered.alternatives.single.category, 'Generic drug');
    });

    test('keeps the generic option when a brand resolves to its generic', () {
      final result = _buildResult(
        query: 'Nurofen',
        medicineName: 'Ibuprofen',
        matchedName: 'Nurofen',
        genericName: 'Ibuprofen',
        alternatives: const <MedicineAlternativeItem>[],
        brandNames: const <String>[],
        activeIngredients: const <String>['Ibuprofen'],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives, hasLength(1));
      expect(filtered.alternatives.single.name, 'Ibuprofen');
      expect(filtered.alternatives.single.category, 'Generic drug');
    });

    test('does not add a salt variant for a generic medicine search', () {
      final result = _buildResult(
        genericName: 'warfarin sodium',
        activeIngredients: const <String>['warfarin sodium'],
        alternatives: const <MedicineAlternativeItem>[
          MedicineAlternativeItem(
            name: 'warfarin sodium 4 MG Oral Tablet',
            category: 'Generic drug',
            termType: 'SCD',
          ),
        ],
      );

      final filtered = removeSameMedicineAlternatives(result);

      expect(filtered.alternatives, isEmpty);
    });
  });
}

MedicineLookupResult _buildResult({
  required List<MedicineAlternativeItem> alternatives,
  String query = 'warfarin',
  String medicineName = 'Warfarin',
  String? matchedName,
  String? genericName = 'warfarin',
  List<String> brandNames = const <String>['Coumadin', 'Jantoven'],
  List<String> activeIngredients = const <String>['warfarin sodium'],
}) {
  return MedicineLookupResult(
    query: query,
    searchMode: 'name',
    medicineName: medicineName,
    matchedName: matchedName,
    genericName: genericName,
    brandNames: brandNames,
    activeIngredients: activeIngredients,
    usedFor: const <String>[],
    dose: const <String>[],
    warnings: const <String>[],
    sideEffects: const <String>[],
    interactions: const <String>[],
    alternatives: alternatives,
    storage: const <String>[],
    disclaimer: const <String>[],
    source: 'test',
  );
}
