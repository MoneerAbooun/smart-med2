import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class MedicationScheduleTime {
  const MedicationScheduleTime({required this.hour, required this.minute});

  static const int _minutesPerDay = 24 * 60;

  final int hour;
  final int minute;

  factory MedicationScheduleTime.fromMap(Map<String, dynamic> map) {
    return MedicationScheduleTime(
      hour: FirestoreValueParser.intOrNull(map['hour']) ?? 0,
      minute: FirestoreValueParser.intOrNull(map['minute']) ?? 0,
    );
  }

  factory MedicationScheduleTime.fromDisplayString(String value) {
    final normalized = value.trim().toUpperCase();
    final meridiemMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s?(AM|PM)$',
    ).firstMatch(normalized);

    if (meridiemMatch != null) {
      int hour = int.parse(meridiemMatch.group(1)!);
      final minute = int.parse(meridiemMatch.group(2)!);
      final period = meridiemMatch.group(3)!;

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return MedicationScheduleTime(hour: hour, minute: minute);
    }

    final twentyFourHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(normalized);

    if (twentyFourHourMatch != null) {
      final hour = int.parse(twentyFourHourMatch.group(1)!);
      final minute = int.parse(twentyFourHourMatch.group(2)!);

      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return MedicationScheduleTime(hour: hour, minute: minute);
      }
    }

    throw FormatException('Invalid time format: $value');
  }

  static MedicationScheduleTime? tryFromDisplayString(String value) {
    try {
      return MedicationScheduleTime.fromDisplayString(value);
    } on FormatException {
      return null;
    }
  }

  static int intervalMinutesForDailyFrequency(int timesPerDay) {
    if (timesPerDay < 1) {
      throw ArgumentError.value(
        timesPerDay,
        'timesPerDay',
        'Times per day must be at least 1.',
      );
    }

    return _minutesPerDay ~/ timesPerDay;
  }

  static List<MedicationScheduleTime> evenlySpaced({
    required MedicationScheduleTime firstTime,
    required int timesPerDay,
  }) {
    final intervalMinutes = intervalMinutesForDailyFrequency(timesPerDay);

    return List<MedicationScheduleTime>.generate(
      timesPerDay,
      (index) => firstTime.addMinutes(intervalMinutes * index),
      growable: false,
    );
  }

  MedicationScheduleTime addMinutes(int minutesToAdd) {
    final totalMinutes = ((hour * 60) + minute + minutesToAdd) % _minutesPerDay;
    final normalizedTotalMinutes = totalMinutes < 0
        ? totalMinutes + _minutesPerDay
        : totalMinutes;

    return MedicationScheduleTime(
      hour: normalizedTotalMinutes ~/ 60,
      minute: normalizedTotalMinutes % 60,
    );
  }

  Map<String, dynamic> toMap() {
    return {'hour': hour, 'minute': minute};
  }

  String toDisplayString() {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    return '$normalizedHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
