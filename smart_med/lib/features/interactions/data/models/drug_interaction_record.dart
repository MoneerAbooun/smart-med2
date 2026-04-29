import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class DrugInteractionRecord {
  const DrugInteractionRecord({
    this.id,
    required this.drugIds,
    this.drugNames = const <String>[],
    required this.severity,
    required this.summary,
    this.warnings = const <String>[],
    this.recommendations = const <String>[],
    this.evidenceLevel,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final List<String> drugIds;
  final List<String> drugNames;
  final String severity;
  final String summary;
  final List<String> warnings;
  final List<String> recommendations;
  final String? evidenceLevel;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DrugInteractionRecord.fromMap(String id, Map<String, dynamic> map) {
    return DrugInteractionRecord(
      id: id,
      drugIds: FirestoreValueParser.stringList(map['drugIds']),
      drugNames: FirestoreValueParser.stringList(map['drugNames']),
      severity: FirestoreValueParser.stringOrNull(map['severity']) ?? 'unknown',
      summary: FirestoreValueParser.stringOrNull(map['summary']) ?? '',
      warnings: FirestoreValueParser.stringList(map['warnings']),
      recommendations: FirestoreValueParser.stringList(map['recommendations']),
      evidenceLevel: FirestoreValueParser.stringOrNull(map['evidenceLevel']),
      source: FirestoreValueParser.stringOrNull(map['source']) ?? 'firestore',
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'drugIds': drugIds,
      'drugNames': drugNames,
      'severity': severity,
      'summary': summary,
      'warnings': warnings,
      'recommendations': recommendations,
      'evidenceLevel': evidenceLevel,
      'source': source,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
