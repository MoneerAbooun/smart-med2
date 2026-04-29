import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class DrugCatalogRecord {
  const DrugCatalogRecord({
    this.id,
    required this.name,
    this.genericName,
    this.brandNames = const <String>[],
    this.normalizedName,
    this.searchPrefixes = const <String>[],
    this.description,
    this.activeIngredients = const <String>[],
    this.doseForms = const <String>[],
    this.strengths = const <String>[],
    this.indications = const <String>[],
    this.contraindications = const <String>[],
    this.warnings = const <String>[],
    this.source,
    required this.isActive,
    this.lastReviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String name;
  final String? genericName;
  final List<String> brandNames;
  final String? normalizedName;
  final List<String> searchPrefixes;
  final String? description;
  final List<String> activeIngredients;
  final List<String> doseForms;
  final List<String> strengths;
  final List<String> indications;
  final List<String> contraindications;
  final List<String> warnings;
  final String? source;
  final bool isActive;
  final DateTime? lastReviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DrugCatalogRecord.fromMap(String id, Map<String, dynamic> map) {
    return DrugCatalogRecord(
      id: id,
      name: FirestoreValueParser.stringOrNull(map['name']) ?? '',
      genericName: FirestoreValueParser.stringOrNull(map['genericName']),
      brandNames: FirestoreValueParser.stringList(map['brandNames']),
      normalizedName: FirestoreValueParser.stringOrNull(map['normalizedName']),
      searchPrefixes: FirestoreValueParser.stringList(map['searchPrefixes']),
      description: FirestoreValueParser.stringOrNull(map['description']),
      activeIngredients: FirestoreValueParser.stringList(
        map['activeIngredients'],
      ),
      doseForms: FirestoreValueParser.stringList(map['doseForms']),
      strengths: FirestoreValueParser.stringList(map['strengths']),
      indications: FirestoreValueParser.stringList(map['indications']),
      contraindications: FirestoreValueParser.stringList(
        map['contraindications'],
      ),
      warnings: FirestoreValueParser.stringList(map['warnings']),
      source: FirestoreValueParser.stringOrNull(map['source']),
      isActive: FirestoreValueParser.boolOrDefault(
        map['isActive'],
        defaultValue: true,
      ),
      lastReviewedAt: FirestoreValueParser.dateTime(map['lastReviewedAt']),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'name': name,
      'genericName': genericName,
      'brandNames': brandNames,
      'normalizedName': normalizedName,
      'searchPrefixes': searchPrefixes,
      'description': description,
      'activeIngredients': activeIngredients,
      'doseForms': doseForms,
      'strengths': strengths,
      'indications': indications,
      'contraindications': contraindications,
      'warnings': warnings,
      'source': source,
      'isActive': isActive,
      'lastReviewedAt': lastReviewedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
