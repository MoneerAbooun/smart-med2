import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/interactions/data/models/drug_interaction_record.dart';

class DrugInteractionRepository {
  DrugInteractionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return FirestorePaths.drugInteractionsCollection(_firestore);
  }

  Future<void> saveInteraction({
    required DrugInteractionRecord interaction,
    String? pairKey,
  }) async {
    final resolvedDrugIds = _normalizeDrugIds(interaction.drugIds);
    if (resolvedDrugIds.length < 2) {
      throw ArgumentError('Drug interactions need at least two drug IDs.');
    }

    final resolvedPairKey = pairKey ?? buildPairKey(resolvedDrugIds);
    final docRef = FirestorePaths.drugInteractionDoc(
      _firestore,
      resolvedPairKey,
    );
    final existing = await docRef.get();
    final payload = interaction.toMap();
    payload['pairKey'] = resolvedPairKey;
    payload['drugIds'] = resolvedDrugIds;
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (interaction.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<DrugInteractionRecord?> getInteractionByPairKey(String pairKey) async {
    final snapshot = await FirestorePaths.drugInteractionDoc(
      _firestore,
      pairKey.trim(),
    ).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return DrugInteractionRecord.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<DrugInteractionRecord?> getInteractionByDrugIds(
    Iterable<String> drugIds,
  ) {
    return getInteractionByPairKey(buildPairKey(drugIds));
  }

  Future<List<DrugInteractionRecord>> listInteractionsForDrug({
    required String drugId,
    int limit = 50,
  }) async {
    final normalizedDrugId = _normalizeDrugId(drugId);
    if (normalizedDrugId.isEmpty) {
      return const <DrugInteractionRecord>[];
    }

    final snapshot = await _collection
        .where('drugIds', arrayContains: normalizedDrugId)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => DrugInteractionRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  static String buildPairKey(Iterable<String> drugIds) {
    final normalizedDrugIds = _normalizeDrugIds(drugIds);
    if (normalizedDrugIds.length < 2) {
      throw ArgumentError('Drug interactions need at least two drug IDs.');
    }

    return normalizedDrugIds.join('__');
  }

  static List<String> _normalizeDrugIds(Iterable<String> drugIds) {
    final normalized = drugIds
        .map(_normalizeDrugId)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    normalized.sort();
    return normalized;
  }

  static String _normalizeDrugId(String drugId) {
    return drugId.trim().toLowerCase();
  }
}

final DrugInteractionRepository drugInteractionRepository =
    DrugInteractionRepository();
