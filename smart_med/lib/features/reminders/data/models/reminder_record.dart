import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class ReminderRecord {
  const ReminderRecord({
    this.id,
    required this.userId,
    required this.medicationId,
    required this.medicationName,
    required this.slotIndex,
    required this.hour,
    required this.minute,
    this.repeatDays = const <int>[],
    required this.timezone,
    this.startDate,
    this.nextTriggerAt,
    this.lastTriggeredAt,
    this.notificationId,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final String medicationId;
  final String medicationName;
  final int slotIndex;
  final int hour;
  final int minute;
  final List<int> repeatDays;
  final String timezone;
  final DateTime? startDate;
  final DateTime? nextTriggerAt;
  final DateTime? lastTriggeredAt;
  final int? notificationId;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ReminderRecord.fromMap(String id, Map<String, dynamic> map) {
    return ReminderRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      medicationId:
          FirestoreValueParser.stringOrNull(map['medicationId']) ?? '',
      medicationName:
          FirestoreValueParser.stringOrNull(map['medicationName']) ?? '',
      slotIndex: FirestoreValueParser.intOrNull(map['slotIndex']) ?? 0,
      hour: FirestoreValueParser.intOrNull(map['hour']) ?? 0,
      minute: FirestoreValueParser.intOrNull(map['minute']) ?? 0,
      repeatDays: FirestoreValueParser.intList(map['repeatDays']),
      timezone: FirestoreValueParser.stringOrNull(map['timezone']) ?? 'UTC',
      startDate: FirestoreValueParser.dateTime(map['startDate']),
      nextTriggerAt: FirestoreValueParser.dateTime(map['nextTriggerAt']),
      lastTriggeredAt: FirestoreValueParser.dateTime(map['lastTriggeredAt']),
      notificationId: FirestoreValueParser.intOrNull(map['notificationId']),
      isEnabled: FirestoreValueParser.boolOrDefault(
        map['isEnabled'],
        defaultValue: true,
      ),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'slotIndex': slotIndex,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays,
      'timezone': timezone,
      'startDate': startDate,
      'nextTriggerAt': nextTriggerAt,
      'lastTriggeredAt': lastTriggeredAt,
      'notificationId': notificationId,
      'isEnabled': isEnabled,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }
}
