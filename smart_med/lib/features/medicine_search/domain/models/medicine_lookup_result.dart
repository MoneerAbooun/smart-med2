String? _stringOrNull(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }

  final seen = <String>{};
  final results = <String>[];

  for (final item in value) {
    final text = item.toString().trim();
    if (text.isEmpty) {
      continue;
    }

    final key = text.toLowerCase();
    if (seen.add(key)) {
      results.add(text);
    }
  }

  return results;
}

class MedicineAlternativeItem {
  const MedicineAlternativeItem({
    required this.name,
    required this.category,
    this.rxcui,
    this.termType,
  });

  final String name;
  final String category;
  final String? rxcui;
  final String? termType;

  factory MedicineAlternativeItem.fromMap(Map<String, dynamic> map) {
    return MedicineAlternativeItem(
      name: map['name']?.toString().trim() ?? '',
      category: map['category']?.toString().trim() ?? 'Alternative',
      rxcui: _stringOrNull(map['rxcui']),
      termType: _stringOrNull(map['term_type'] ?? map['termType']),
    );
  }

  String get displayLabel {
    if (category.trim().isEmpty || category.trim() == 'Alternative') {
      return name;
    }

    return '$name (${category.trim()})';
  }
}

class MedicineLookupResult {
  const MedicineLookupResult({
    required this.query,
    required this.searchMode,
    required this.medicineName,
    required this.brandNames,
    required this.activeIngredients,
    required this.usedFor,
    required this.dose,
    required this.warnings,
    required this.sideEffects,
    required this.interactions,
    required this.alternatives,
    required this.storage,
    required this.disclaimer,
    required this.source,
    this.matchedName,
    this.genericName,
    this.identificationReason,
    this.rxcui,
    this.setId,
  });

  final String query;
  final String searchMode;
  final String medicineName;
  final String? matchedName;
  final String? genericName;
  final List<String> brandNames;
  final List<String> activeIngredients;
  final List<String> usedFor;
  final List<String> dose;
  final List<String> warnings;
  final List<String> sideEffects;
  final List<String> interactions;
  final List<MedicineAlternativeItem> alternatives;
  final List<String> storage;
  final List<String> disclaimer;
  final String source;
  final String? identificationReason;
  final String? rxcui;
  final String? setId;

  bool get isImageSearch => searchMode.trim().toLowerCase() == 'image';

  MedicineLookupResult copyWith({
    String? query,
    String? searchMode,
    String? medicineName,
    String? matchedName,
    String? genericName,
    List<String>? brandNames,
    List<String>? activeIngredients,
    List<String>? usedFor,
    List<String>? dose,
    List<String>? warnings,
    List<String>? sideEffects,
    List<String>? interactions,
    List<MedicineAlternativeItem>? alternatives,
    List<String>? storage,
    List<String>? disclaimer,
    String? source,
    String? identificationReason,
    String? rxcui,
    String? setId,
  }) {
    return MedicineLookupResult(
      query: query ?? this.query,
      searchMode: searchMode ?? this.searchMode,
      medicineName: medicineName ?? this.medicineName,
      matchedName: matchedName ?? this.matchedName,
      genericName: genericName ?? this.genericName,
      brandNames: brandNames ?? this.brandNames,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      usedFor: usedFor ?? this.usedFor,
      dose: dose ?? this.dose,
      warnings: warnings ?? this.warnings,
      sideEffects: sideEffects ?? this.sideEffects,
      interactions: interactions ?? this.interactions,
      alternatives: alternatives ?? this.alternatives,
      storage: storage ?? this.storage,
      disclaimer: disclaimer ?? this.disclaimer,
      source: source ?? this.source,
      identificationReason: identificationReason ?? this.identificationReason,
      rxcui: rxcui ?? this.rxcui,
      setId: setId ?? this.setId,
    );
  }

  factory MedicineLookupResult.fromMap(Map<String, dynamic> map) {
    return MedicineLookupResult(
      query: map['query']?.toString().trim() ?? '',
      searchMode: map['search_mode']?.toString().trim() ?? 'name',
      medicineName: map['medicine_name']?.toString().trim() ?? '',
      matchedName: _stringOrNull(map['matched_name'] ?? map['matchedName']),
      genericName: _stringOrNull(map['generic_name'] ?? map['genericName']),
      brandNames: _stringList(map['brand_names'] ?? map['brandNames']),
      activeIngredients: _stringList(
        map['active_ingredients'] ?? map['activeIngredients'],
      ),
      usedFor: _stringList(map['used_for'] ?? map['usedFor']),
      dose: _stringList(map['dose']),
      warnings: _stringList(map['warnings']),
      sideEffects: _stringList(map['side_effects'] ?? map['sideEffects']),
      interactions: _stringList(map['interactions']),
      alternatives: _alternativeList(map['alternatives']),
      storage: _stringList(map['storage']),
      disclaimer: _stringList(map['disclaimer']),
      source: map['source']?.toString().trim() ?? 'rxnorm+dailymed+openfda',
      identificationReason: _stringOrNull(
        map['identification_reason'] ?? map['identificationReason'],
      ),
      rxcui: _stringOrNull(map['rxcui']),
      setId: _stringOrNull(map['set_id'] ?? map['setId']),
    );
  }

  static List<MedicineAlternativeItem> _alternativeList(dynamic value) {
    if (value is! List) {
      return const <MedicineAlternativeItem>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              MedicineAlternativeItem.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  }
}
