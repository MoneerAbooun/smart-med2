import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/core/services/notification_preferences_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPreferencesRepository', () {
    late NotificationPreferencesRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = NotificationPreferencesRepository();
    });

    test('defaults notifications to enabled', () async {
      final isEnabled = await repository.loadNotificationsEnabled();

      expect(isEnabled, isTrue);
    });

    test('persists the notifications enabled flag', () async {
      await repository.setNotificationsEnabled(false);
      final disabled = await repository.loadNotificationsEnabled();
      expect(disabled, isFalse);

      await repository.setNotificationsEnabled(true);
      final enabled = await repository.loadNotificationsEnabled();
      expect(enabled, isTrue);
    });
  });
}
