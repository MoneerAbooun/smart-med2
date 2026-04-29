import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesRepository {
  static const String _notificationsEnabledKey = 'notifications.enabled';

  Future<bool> loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
  }
}

final NotificationPreferencesRepository notificationPreferencesRepository =
    NotificationPreferencesRepository();
