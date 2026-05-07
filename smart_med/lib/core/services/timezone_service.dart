import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  const TimezoneService._();

  static Future<void> initializeLocalTimezone() async {
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timezone = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to initialize local timezone from platform: $error');
        debugPrint(stackTrace.toString());
      }

      try {
        final String fallbackTimeZone = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(fallbackTimeZone));
      } catch (_) {
        if (kDebugMode) {
          debugPrint('Failed to set fallback local timezone.');
        }
      }
    }
  }
}
