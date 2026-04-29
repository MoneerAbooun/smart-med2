import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:smart_med/models/local_medicine.dart';

class LocalMedicineService {
  LocalMedicineService({
    AssetBundle? bundle,
    String assetPath = _defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle,
       _assetPath = assetPath;

  static const String _defaultAssetPath = 'assets/data/local_medicines.json';
  static const int _maxResults = 20;

  final AssetBundle _bundle;
  final String _assetPath;

  List<LocalMedicine>? _cachedMedicines;
  Future<List<LocalMedicine>>? _pendingLoad;

  Future<List<LocalMedicine>> loadMedicines() async {
    final cachedMedicines = _cachedMedicines;
    if (cachedMedicines != null) {
      return cachedMedicines;
    }

    final pendingLoad = _pendingLoad;
    if (pendingLoad != null) {
      return pendingLoad;
    }

    final loadFuture = _loadMedicines();
    _pendingLoad = loadFuture;
    return loadFuture;
  }

  Future<List<LocalMedicine>> searchMedicines(String query) async {
    final normalizedQuery = _normalizeForSearch(query);
    if (normalizedQuery.isEmpty) {
      return const <LocalMedicine>[];
    }

    final queryTokens = normalizedQuery.split(' ');
    final medicines = await loadMedicines();

    return medicines
        .where(
          (medicine) => _matchesMedicine(
            medicine: medicine,
            queryTokens: queryTokens,
          ),
        )
        .take(_maxResults)
        .toList(growable: false);
  }

  Future<List<LocalMedicine>> _loadMedicines() async {
    try {
      final rawJson = await _bundle.loadString(_assetPath);
      final decoded = jsonDecode(rawJson);
      final medicines = List<LocalMedicine>.unmodifiable(
        _parseMedicines(decoded),
      );
      _cachedMedicines = medicines;
      return medicines;
    } on Object {
      _cachedMedicines = const <LocalMedicine>[];
      return _cachedMedicines!;
    } finally {
      _pendingLoad = null;
    }
  }

  List<LocalMedicine> _parseMedicines(dynamic decoded) {
    if (decoded is List) {
      return _parseMedicineList(decoded);
    }

    if (decoded is Map<String, dynamic>) {
      final nestedItems =
          decoded['medicines'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['results'];
      if (nestedItems is List) {
        return _parseMedicineList(nestedItems);
      }
    }

    return const <LocalMedicine>[];
  }

  List<LocalMedicine> _parseMedicineList(List<dynamic> items) {
    final medicines = <LocalMedicine>[];

    for (final item in items.whereType<Map>()) {
      try {
        final normalizedItem = <String, dynamic>{};
        item.forEach((key, value) {
          normalizedItem[key.toString()] = value;
        });
        medicines.add(LocalMedicine.fromMap(normalizedItem));
      } on Object {
        continue;
      }
    }

    return List<LocalMedicine>.unmodifiable(medicines);
  }

  bool _matchesMedicine({
    required LocalMedicine medicine,
    required List<String> queryTokens,
  }) {
    final normalizedTerms = medicine.searchableTerms
        .map(_normalizeForSearch)
        .where((term) => term.isNotEmpty)
        .join(' ');

    if (normalizedTerms.isEmpty) {
      return false;
    }

    return queryTokens.every(normalizedTerms.contains);
  }

  // Keep Arabic and English search forgiving by removing case and common
  // Arabic orthographic variations before matching.
  String _normalizeForSearch(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll(RegExp(r'[\u0610-\u061A\u0640\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), ' ')
        .replaceAll('\u0623', '\u0627')
        .replaceAll('\u0625', '\u0627')
        .replaceAll('\u0622', '\u0627')
        .replaceAll('\u0671', '\u0627')
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0626', '\u064A')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0629', '\u0647')
        .replaceAll(RegExp(r'\s+'), ' ');

    return normalized.trim();
  }
}

final LocalMedicineService localMedicineService = LocalMedicineService();
