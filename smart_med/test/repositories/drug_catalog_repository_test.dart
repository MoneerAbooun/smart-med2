import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/drug_library/data/drug_catalog_repository.dart';
import 'package:smart_med/features/drug_library/data/models/drug_catalog_record.dart';

void main() {
  group('DrugCatalogRepository', () {
    late FakeFirebaseFirestore firestore;
    late DrugCatalogRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = DrugCatalogRepository(firestore: firestore);
    });

    test(
      'saveDrug writes normalized search fields for catalog search',
      () async {
        await repository.saveDrug(
          drug: const DrugCatalogRecord(
            name: 'Ibuprofen',
            genericName: 'Ibuprofen',
            brandNames: ['Advil', 'Motrin'],
            doseForms: ['tablet'],
            strengths: ['200 mg'],
            isActive: true,
          ),
          drugId: 'ibuprofen',
        );

        final snapshot = await FirestorePaths.drugCatalogDoc(
          firestore,
          'ibuprofen',
        ).get();

        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['normalizedName'], 'ibuprofen');
        expect(snapshot.data()!['searchPrefixes'], containsAll(['ibu', 'adv']));
      },
    );

    test('searchDrugs matches generic and brand prefixes', () async {
      await repository.saveDrug(
        drug: const DrugCatalogRecord(
          name: 'Ibuprofen',
          genericName: 'Ibuprofen',
          brandNames: ['Advil'],
          isActive: true,
        ),
        drugId: 'ibuprofen',
      );
      await repository.saveDrug(
        drug: const DrugCatalogRecord(
          name: 'Paracetamol',
          genericName: 'Acetaminophen',
          brandNames: ['Tylenol'],
          isActive: true,
        ),
        drugId: 'acetaminophen',
      );

      final brandResults = await repository.searchDrugs('adv');
      final genericResults = await repository.searchDrugs('ace');

      expect(brandResults.map((item) => item.id), ['ibuprofen']);
      expect(genericResults.map((item) => item.id), ['acetaminophen']);
    });

    test('searchDrugs filters inactive drugs', () async {
      await repository.saveDrug(
        drug: const DrugCatalogRecord(
          name: 'Legacy Drug',
          brandNames: ['OldBrand'],
          isActive: false,
        ),
        drugId: 'legacy-drug',
      );

      final results = await repository.searchDrugs('old');

      expect(results, isEmpty);
    });
  });
}
