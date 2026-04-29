import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';

class MedicineNameRepositoryException implements Exception {
  const MedicineNameRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MedicineNameRepository {
  MedicineNameRepository({
    AssetBundle? bundle,
    String assetPath = _defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle,
       _assetPath = assetPath;

  static const String _defaultAssetPath = 'assets/data/local_medicines.json';

  final AssetBundle _bundle;
  final String _assetPath;

  List<MedicineNameEntry>? _cachedEntries;
  Future<List<MedicineNameEntry>>? _pendingLoad;

  Future<List<MedicineNameEntry>> loadEntries() async {
    final cachedEntries = _cachedEntries;
    if (cachedEntries != null) {
      return cachedEntries;
    }

    final pendingLoad = _pendingLoad;
    if (pendingLoad != null) {
      return pendingLoad;
    }

    final loadFuture = _loadEntries();
    _pendingLoad = loadFuture;
    return loadFuture;
  }

  Future<List<MedicineNameEntry>> _loadEntries() async {
    try {
      final rawJson = await _bundle.loadString(_assetPath);
      final decoded = jsonDecode(rawJson);
      final entries = List<MedicineNameEntry>.unmodifiable(
        _parseEntries(decoded),
      );
      _cachedEntries = entries;
      return entries;
    } on MedicineNameRepositoryException {
      rethrow;
    } on Object {
      throw const MedicineNameRepositoryException(
        'The local medicine name list could not be loaded.',
      );
    } finally {
      _pendingLoad = null;
    }
  }

  List<MedicineNameEntry> _parseEntries(dynamic decoded) {
    if (decoded is List) {
      return _parseEntryList(decoded);
    }

    if (decoded is Map<String, dynamic>) {
      final nestedItems =
          decoded['medicines'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['results'];
      if (nestedItems is List) {
        return _parseEntryList(nestedItems);
      }
    }

    throw const MedicineNameRepositoryException(
      'The local medicine name list has an unsupported JSON structure.',
    );
  }

  List<MedicineNameEntry> _parseEntryList(List<dynamic> items) {
    final entries = <MedicineNameEntry>[];

    for (final item in items.whereType<Map>()) {
      try {
        final normalizedItem = <String, dynamic>{};
        item.forEach((key, value) {
          normalizedItem[key.toString()] = value;
        });
        entries.add(MedicineNameEntry.fromMap(normalizedItem));
      } on Object {
        continue;
      }
    }

    return entries;
  }
}

final MedicineNameRepository medicineNameRepository = MedicineNameRepository();
