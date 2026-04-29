import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/services/notification_service.dart';

void main() {
  test('generateNotificationId returns a valid Android notification id', () {
    for (int i = 0; i < 1000; i++) {
      final id = NotificationService.generateNotificationId();

      expect(id, greaterThan(0));
      expect(id, lessThan(0x80000000));
    }
  });
}
