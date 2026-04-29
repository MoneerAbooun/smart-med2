class DrugInteractionLookupResult {
  const DrugInteractionLookupResult({
    required this.firstQuery,
    required this.secondQuery,
    required this.firstDrug,
    required this.secondDrug,
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

  factory DrugInteractionLookupResult.fromMap(Map<String, dynamic> map) {
    return DrugInteractionLookupResult(
      firstQuery: map['first_query']?.toString() ?? '',
      secondQuery: map['second_query']?.toString() ?? '',
      firstDrug: map['first_drug']?.toString() ?? '',
      secondDrug: map['second_drug']?.toString() ?? '',
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
