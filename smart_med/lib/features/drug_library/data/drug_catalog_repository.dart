import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/drug_library/data/models/drug_alternative_record.dart';
import 'package:smart_med/features/drug_library/data/models/drug_catalog_record.dart';

class DrugCatalogRepository {
  DrugCatalogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _drugCatalogCollection {
    return FirestorePaths.drugCatalogCollection(_firestore);
  }

  Future<void> saveDrug({
    required DrugCatalogRecord drug,
    String? drugId,
  }) async {
    final docRef = drugId == null
        ? _drugCatalogCollection.doc()
        : FirestorePaths.drugCatalogDoc(_firestore, drugId);

    final existing = await docRef.get();
    final payload = drug.toMap();
    payload['normalizedName'] = _normalizedNameFor(drug);
    payload['searchPrefixes'] = _searchPrefixesFor(
      drug,
    ).toList(growable: false);
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (drug.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<DrugCatalogRecord?> getDrug({required String drugId}) async {
    final snapshot = await FirestorePaths.drugCatalogDoc(
      _firestore,
      drugId,
    ).get();
    if (!snapshot.exists) {
      return null;
    }

    return DrugCatalogRecord.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<List<DrugCatalogRecord>> listDrugs({int limit = 50}) async {
    final snapshot = await _drugCatalogCollection.limit(limit).get();
    return snapshot.docs
        .map((doc) => DrugCatalogRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<List<DrugCatalogRecord>> searchDrugs(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = _normalizeSearchTerm(query);
    if (normalizedQuery.isEmpty) {
      return const <DrugCatalogRecord>[];
    }

    final snapshot = await _drugCatalogCollection
        .where('isActive', isEqualTo: true)
        .where('searchPrefixes', arrayContains: normalizedQuery)
        .limit(limit)
        .get();

    final results = snapshot.docs
        .map((doc) => DrugCatalogRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);

    results.sort(
      (left, right) => _compareSearchResults(left, right, normalizedQuery),
    );

    return results;
  }

  Stream<List<DrugAlternativeRecord>> watchAlternatives({
    required String drugId,
  }) {
    return FirestorePaths.alternativesCollection(
      _firestore,
      drugId,
    ).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => DrugAlternativeRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<List<DrugAlternativeRecord>> listAlternatives({
    required String drugId,
  }) async {
    final snapshot = await FirestorePaths.alternativesCollection(
      _firestore,
      drugId,
    ).get();
    return snapshot.docs
        .map((doc) => DrugAlternativeRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveAlternative({
    required String drugId,
    required DrugAlternativeRecord alternative,
    String? alternativeId,
  }) async {
    final docRef = alternativeId == null
        ? FirestorePaths.alternativesCollection(_firestore, drugId).doc()
        : FirestorePaths.alternativeDoc(_firestore, drugId, alternativeId);

    final existing = await docRef.get();
    final payload = alternative.toMap();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (alternative.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }

  static int _compareSearchResults(
    DrugCatalogRecord left,
    DrugCatalogRecord right,
    String normalizedQuery,
  ) {
    final leftScore = _searchScore(left, normalizedQuery);
    final rightScore = _searchScore(right, normalizedQuery);

    if (leftScore != rightScore) {
      return leftScore.compareTo(rightScore);
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  static int _searchScore(DrugCatalogRecord drug, String normalizedQuery) {
    final candidates = _searchCandidatesFor(drug);

    if (candidates.any((candidate) => candidate == normalizedQuery)) {
      return 0;
    }

    if (candidates.any((candidate) => candidate.startsWith(normalizedQuery))) {
      return 1;
    }

    if (candidates.any(
      (candidate) => candidate
          .split(' ')
          .any((token) => token.startsWith(normalizedQuery)),
    )) {
      return 2;
    }

    return 3;
  }

  static Iterable<String> _searchCandidatesFor(DrugCatalogRecord drug) sync* {
    final normalizedName = _normalizeSearchTerm(drug.name);
    if (normalizedName.isNotEmpty) {
      yield normalizedName;
    }

    final normalizedGenericName = _normalizeSearchTerm(drug.genericName ?? '');
    if (normalizedGenericName.isNotEmpty) {
      yield normalizedGenericName;
    }

    for (final brandName in drug.brandNames) {
      final normalizedBrandName = _normalizeSearchTerm(brandName);
      if (normalizedBrandName.isNotEmpty) {
        yield normalizedBrandName;
      }
    }
  }

  static String _normalizedNameFor(DrugCatalogRecord drug) {
    final explicitNormalizedName = _normalizeSearchTerm(
      drug.normalizedName ?? '',
    );
    if (explicitNormalizedName.isNotEmpty) {
      return explicitNormalizedName;
    }

    return _normalizeSearchTerm(drug.name);
  }

  static Set<String> _searchPrefixesFor(DrugCatalogRecord drug) {
    final prefixes = <String>{};

    for (final candidate in _searchCandidatesFor(drug)) {
      prefixes.addAll(_prefixesFor(candidate));

      for (final token in candidate.split(' ')) {
        if (token.isNotEmpty) {
          prefixes.addAll(_prefixesFor(token));
        }
      }
    }

    for (final explicitPrefix in drug.searchPrefixes) {
      final normalizedPrefix = _normalizeSearchTerm(explicitPrefix);
      if (normalizedPrefix.isNotEmpty) {
        prefixes.add(normalizedPrefix);
      }
    }

    return prefixes;
  }

  static Iterable<String> _prefixesFor(String value) sync* {
    for (var index = 1; index <= value.length; index++) {
      yield value.substring(0, index);
    }
  }

  static String _normalizeSearchTerm(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

final DrugCatalogRepository drugCatalogRepository = DrugCatalogRepository();
