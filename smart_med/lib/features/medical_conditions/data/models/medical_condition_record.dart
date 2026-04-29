import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class MedicalConditionRecord {
  const MedicalConditionRecord({
    this.id,
    required this.userId,
    required this.name,
    required this.status,
    this.diagnosedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final String name;
  final String status;
  final DateTime? diagnosedAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MedicalConditionRecord.fromMap(String id, Map<String, dynamic> map) {
    return MedicalConditionRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      name: FirestoreValueParser.stringOrNull(map['name']) ?? '',
      status: FirestoreValueParser.stringOrNull(map['status']) ?? 'active',
      diagnosedAt: FirestoreValueParser.dateTime(map['diagnosedAt']),
      notes: FirestoreValueParser.stringOrNull(map['notes']),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'name': name,
      'status': status,
      'diagnosedAt': diagnosedAt,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
