class DrugInteractionLookupResult {
  const DrugInteractionLookupResult({
    required this.firstQuery,
    required this.secondQuery,
    required this.firstDrug,
    required this.secondDrug,
    this.firstInputName,
    this.secondInputName,
    this.firstLocalBrandName,
    this.firstLocalGenericName,
    this.secondLocalBrandName,
    this.secondLocalGenericName,
    this.firstGenericName,
    this.secondGenericName,
    this.firstRxcui,
    this.secondRxcui,
    this.firstSetId,
    this.secondSetId,
    required this.severity,
    required this.summary,
    this.mechanism,
    this.warnings = const <String>[],
    this.recommendations = const <String>[],
    this.evidence = const <String>[],
    required this.source,
  });

  final String firstQuery;
  final String secondQuery;
  final String firstDrug;
  final String secondDrug;
  final String? firstInputName;
  final String? secondInputName;
  final String? firstLocalBrandName;
  final String? firstLocalGenericName;
  final String? secondLocalBrandName;
  final String? secondLocalGenericName;
  final String? firstGenericName;
  final String? secondGenericName;
  final String? firstRxcui;
  final String? secondRxcui;
  final String? firstSetId;
  final String? secondSetId;
  final String severity;
  final String summary;
  final String? mechanism;
  final List<String> warnings;
  final List<String> recommendations;
  final List<String> evidence;
  final String source;

  List<String> get queryDrugIds {
    final ids = <String>{
      _normalizeDrugId(firstQuery),
      _normalizeDrugId(secondQuery),
    }.where((item) => item.isNotEmpty).toList(growable: false);
    ids.sort();
    return ids;
  }

  List<String> get displayDrugNames => <String>[firstDrug, secondDrug];

  String get firstEnteredName => _stringOrNull(firstInputName) ?? firstQuery;

  String get secondEnteredName => _stringOrNull(secondInputName) ?? secondQuery;

  factory DrugInteractionLookupResult.fromMap(Map<String, dynamic> map) {
    return DrugInteractionLookupResult(
      firstQuery: map['first_query']?.toString() ?? '',
      secondQuery: map['second_query']?.toString() ?? '',
      firstDrug: map['first_drug']?.toString() ?? '',
      secondDrug: map['second_drug']?.toString() ?? '',
      firstInputName: _stringOrNull(map['first_input_name']),
      secondInputName: _stringOrNull(map['second_input_name']),
      firstLocalBrandName: _stringOrNull(map['first_local_brand_name']),
      firstLocalGenericName: _stringOrNull(map['first_local_generic_name']),
      secondLocalBrandName: _stringOrNull(map['second_local_brand_name']),
      secondLocalGenericName: _stringOrNull(map['second_local_generic_name']),
      firstGenericName: _stringOrNull(map['first_generic_name']),
      secondGenericName: _stringOrNull(map['second_generic_name']),
      firstRxcui: _stringOrNull(map['first_rxcui']),
      secondRxcui: _stringOrNull(map['second_rxcui']),
      firstSetId: _stringOrNull(map['first_set_id']),
      secondSetId: _stringOrNull(map['second_set_id']),
      severity: map['severity']?.toString() ?? 'Unknown',
      summary: map['summary']?.toString() ?? '',
      mechanism: _stringOrNull(map['mechanism']),
      warnings: _stringList(map['warnings']),
      recommendations: _stringList(map['recommendations']),
      evidence: _stringList(map['evidence']),
      source: map['source']?.toString() ?? 'api',
    );
  }

  DrugInteractionLookupResult copyWith({
    String? firstQuery,
    String? secondQuery,
    String? firstDrug,
    String? secondDrug,
    String? firstInputName,
    String? secondInputName,
    String? firstLocalBrandName,
    String? firstLocalGenericName,
    String? secondLocalBrandName,
    String? secondLocalGenericName,
    String? firstGenericName,
    String? secondGenericName,
    String? firstRxcui,
    String? secondRxcui,
    String? firstSetId,
    String? secondSetId,
    String? severity,
    String? summary,
    String? mechanism,
    List<String>? warnings,
    List<String>? recommendations,
    List<String>? evidence,
    String? source,
  }) {
    return DrugInteractionLookupResult(
      firstQuery: firstQuery ?? this.firstQuery,
      secondQuery: secondQuery ?? this.secondQuery,
      firstDrug: firstDrug ?? this.firstDrug,
      secondDrug: secondDrug ?? this.secondDrug,
      firstInputName: firstInputName ?? this.firstInputName,
      secondInputName: secondInputName ?? this.secondInputName,
      firstLocalBrandName: firstLocalBrandName ?? this.firstLocalBrandName,
      firstLocalGenericName:
          firstLocalGenericName ?? this.firstLocalGenericName,
      secondLocalBrandName: secondLocalBrandName ?? this.secondLocalBrandName,
      secondLocalGenericName:
          secondLocalGenericName ?? this.secondLocalGenericName,
      firstGenericName: firstGenericName ?? this.firstGenericName,
      secondGenericName: secondGenericName ?? this.secondGenericName,
      firstRxcui: firstRxcui ?? this.firstRxcui,
      secondRxcui: secondRxcui ?? this.secondRxcui,
      firstSetId: firstSetId ?? this.firstSetId,
      secondSetId: secondSetId ?? this.secondSetId,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      mechanism: mechanism ?? this.mechanism,
      warnings: warnings ?? this.warnings,
      recommendations: recommendations ?? this.recommendations,
      evidence: evidence ?? this.evidence,
      source: source ?? this.source,
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeDrugId(String value) {
    return value.trim().toLowerCase();
  }
}
