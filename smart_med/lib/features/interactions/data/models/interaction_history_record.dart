import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class InteractionHistoryRecord {
  const InteractionHistoryRecord({
    this.id,
    required this.userId,
    required this.medicationIds,
    required this.drugNames,
    required this.severity,
    required this.summary,
    this.warnings = const <String>[],
    this.recommendations = const <String>[],
    this.checkedAt,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final List<String> medicationIds;
  final List<String> drugNames;
  final String severity;
  final String summary;
  final List<String> warnings;
  final List<String> recommendations;
  final DateTime? checkedAt;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InteractionHistoryRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return InteractionHistoryRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      medicationIds: FirestoreValueParser.stringList(map['medicationIds']),
      drugNames: FirestoreValueParser.stringList(map['drugNames']),
      severity: FirestoreValueParser.stringOrNull(map['severity']) ?? 'unknown',
      summary: FirestoreValueParser.stringOrNull(map['summary']) ?? '',
      warnings: FirestoreValueParser.stringList(map['warnings']),
      recommendations: FirestoreValueParser.stringList(
        map['recommendations'],
      ),
      checkedAt: FirestoreValueParser.dateTime(map['checkedAt']),
      source: FirestoreValueParser.stringOrNull(map['source']) ?? 'firestore',
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'medicationIds': medicationIds,
      'drugNames': drugNames,
      'severity': severity,
      'summary': summary,
      'warnings': warnings,
      'recommendations': recommendations,
      'checkedAt': checkedAt,
      'source': source,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
