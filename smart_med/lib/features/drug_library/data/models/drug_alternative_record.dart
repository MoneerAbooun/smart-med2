import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class DrugAlternativeRecord {
  const DrugAlternativeRecord({
    this.id,
    required this.alternativeDrugId,
    required this.name,
    this.genericName,
    this.reason,
    this.category,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String alternativeDrugId;
  final String name;
  final String? genericName;
  final String? reason;
  final String? category;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DrugAlternativeRecord.fromMap(String id, Map<String, dynamic> map) {
    return DrugAlternativeRecord(
      id: id,
      alternativeDrugId:
          FirestoreValueParser.stringOrNull(map['alternativeDrugId']) ?? '',
      name: FirestoreValueParser.stringOrNull(map['name']) ?? '',
      genericName: FirestoreValueParser.stringOrNull(map['genericName']),
      reason: FirestoreValueParser.stringOrNull(map['reason']),
      category: FirestoreValueParser.stringOrNull(map['category']),
      notes: FirestoreValueParser.stringOrNull(map['notes']),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'alternativeDrugId': alternativeDrugId,
      'name': name,
      'genericName': genericName,
      'reason': reason,
      'category': category,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
