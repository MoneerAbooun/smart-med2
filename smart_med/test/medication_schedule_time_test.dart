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
}
