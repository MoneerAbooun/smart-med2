import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class AllergyRecord {
  const AllergyRecord({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.severity,
    this.reaction,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final String name;
  final String type;
  final String? severity;
  final String? reaction;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AllergyRecord.fromMap(String id, Map<String, dynamic> map) {
    return AllergyRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      name: FirestoreValueParser.stringOrNull(map['name']) ?? '',
      type: FirestoreValueParser.stringOrNull(map['type']) ?? 'drug',
      severity: FirestoreValueParser.stringOrNull(map['severity']),
      reaction: FirestoreValueParser.stringOrNull(map['reaction']),
      notes: FirestoreValueParser.stringOrNull(map['notes']),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'name': name,
      'type': type,
      'severity': severity,
      'reaction': reaction,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
