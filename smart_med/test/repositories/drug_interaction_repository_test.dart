import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_repository.dart';
import 'package:smart_med/features/interactions/data/models/drug_interaction_record.dart';

void main() {
  group('DrugInteractionRepository', () {
    late FakeFirebaseFirestore firestore;
    late DrugInteractionRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = DrugInteractionRepository(firestore: firestore);
    });

    test('buildPairKey normalizes and sorts drug IDs', () {
      final pairKey = DrugInteractionRepository.buildPairKey([
        ' Warfarin ',
        'ibuprofen',
      ]);

      expect(pairKey, 'ibuprofen__warfarin');
    });

    test('saveInteraction stores the record under the pair key', () async {
      await repository.saveInteraction(
        interaction: const DrugInteractionRecord(
          drugIds: ['Warfarin', 'ibuprofen'],
          drugNames: ['Warfarin', 'Ibuprofen'],
          severity: 'major',
          summary: 'Increased bleeding risk',
          warnings: ['Bleeding'],
          recommendations: ['Avoid without clinical review'],
          source: 'manual-seed',
        ),
      );

      final snapshot = await FirestorePaths.drugInteractionDoc(
        firestore,
        'ibuprofen__warfarin',
      ).get();
      final interaction = await repository.getInteractionByDrugIds([
        'ibuprofen',
        'warfarin',
      ]);

      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['drugIds'], ['ibuprofen', 'warfarin']);
      expect(interaction, isNotNull);
      expect(interaction!.severity, 'major');
      expect(interaction.summary, 'Increased bleeding risk');
    });
  });
}
