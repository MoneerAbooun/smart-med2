import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class MedicationDoseHistoryRecord {
  const MedicationDoseHistoryRecord({
    this.id,
    required this.userId,
    required this.doseKey,
    this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.doseAmount,
    required this.doseUnit,
    required this.scheduledAt,
    required this.recordedAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  static const String statusTaken = 'taken';
  static const String statusSkipped = 'skipped';

  final String? id;
  final String userId;
  final String doseKey;
  final String? medicationId;
  final String medicationName;
  final String dosage;
  final double doseAmount;
  final String doseUnit;
  final DateTime scheduledAt;
  final DateTime recordedAt;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTaken => status == statusTaken;
  bool get isSkipped => status == statusSkipped;

  factory MedicationDoseHistoryRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return MedicationDoseHistoryRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      doseKey: FirestoreValueParser.stringOrNull(map['doseKey']) ?? id,
      medicationId: FirestoreValueParser.stringOrNull(map['medicationId']),
      medicationName:
          FirestoreValueParser.stringOrNull(map['medicationName']) ?? 'Unknown',
      dosage: FirestoreValueParser.stringOrNull(map['dosage']) ?? '',
      doseAmount: FirestoreValueParser.doubleOrNull(map['doseAmount']) ?? 0,
      doseUnit: FirestoreValueParser.stringOrNull(map['doseUnit']) ?? '',
      scheduledAt:
          FirestoreValueParser.dateTime(map['scheduledAt']) ?? DateTime(1970),
      recordedAt:
          FirestoreValueParser.dateTime(map['recordedAt']) ?? DateTime(1970),
      status: FirestoreValueParser.stringOrNull(map['status']) ?? statusSkipped,
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'doseKey': doseKey,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
      'scheduledAt': scheduledAt,
      'recordedAt': recordedAt,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
