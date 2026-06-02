import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';

void main() {
  group('MedicationScheduleTime.evenlySpaced', () {
    test('returns reminder times every six hours for four daily doses', () {
      final schedule = MedicationScheduleTime.evenlySpaced(
        firstTime: MedicationScheduleTime(hour: 8, minute: 0),
        timesPerDay: 4,
      );

      expect(schedule.map((item) => item.toDisplayString()).toList(), [
        '8:00 AM',
        '2:00 PM',
        '8:00 PM',
        '2:00 AM',
      ]);
    });

    test(
      'returns reminder times every four hours and 48 minutes for five doses',
      () {
        final schedule = MedicationScheduleTime.evenlySpaced(
          firstTime: MedicationScheduleTime(hour: 8, minute: 0),
          timesPerDay: 5,
        );

        expect(schedule.map((item) => item.toDisplayString()).toList(), [
          '8:00 AM',
          '12:48 PM',
          '5:36 PM',
          '10:24 PM',
          '3:12 AM',
        ]);
      },
    );
  });

  test('intervalMinutesForDailyFrequency rejects values below one', () {
    expect(
      () => MedicationScheduleTime.intervalMinutesForDailyFrequency(0),
      throwsArgumentError,
    );
  });

  group('MedicationScheduleTime.fromDisplayString', () {
    test('still parses 24-hour time without a meridiem marker', () {
      final time = MedicationScheduleTime.fromDisplayString('08:30');

      expect(time.hour, 8);
      expect(time.minute, 30);
    });

    test('parses Arabic PM marker from localized time picker output', () {
      final time = MedicationScheduleTime.fromDisplayString('12:00 \u0645');

      expect(time.hour, 12);
      expect(time.minute, 0);
    });

    test('parses Arabic AM marker and Arabic-Indic digits', () {
      final time = MedicationScheduleTime.fromDisplayString(
        '\u0661\u0662:\u0663\u0660 \u0635',
      );

      expect(time.hour, 0);
      expect(time.minute, 30);
    });

    test('parses leading Arabic PM marker from RTL-rendered input', () {
      final time = MedicationScheduleTime.fromDisplayString('\u0645 1:15');

      expect(time.hour, 13);
      expect(time.minute, 15);
    });
  });
}
