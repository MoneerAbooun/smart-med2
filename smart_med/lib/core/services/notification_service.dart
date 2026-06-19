import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/core/services/notification_preferences_repository.dart';
import 'package:smart_med/core/services/timezone_service.dart';
import 'package:smart_med/core/utils/localized_time_parser.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/reminders/data/reminder_sync_service.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static final Random _random = Random();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'med_channel',
        'Medication Reminders',
        channelDescription: 'Medication reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  static Future<void> init() async {
    if (_isInitialized) return;

    await TimezoneService.initializeLocalTimezone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(settings);
    _isInitialized = true;
  }

  static Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final bool? granted = await androidImplementation
        ?.requestNotificationsPermission();

    return granted ?? false;
  }

  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!await areNotificationsEnabled()) {
      return;
    }

    await _flutterLocalNotificationsPlugin.show(
      generateNotificationId(),
      title,
      body,
      _notificationDetails,
    );
  }

  static int generateNotificationId() {
    final int timestamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    final int randomPart = _random.nextInt(1000);
    final int id = (timestamp * 1000) + randomPart;
    return id == 0 ? 1 : id;
  }

  static int generateStableNotificationId({
    required String userId,
    required String medicationKey,
    required int index,
    required String timeString,
  }) {
    final String source =
        '${userId}_${medicationKey}_${index}_${timeString.trim()}';
    int hash = 0;

    for (int i = 0; i < source.length; i++) {
      hash = ((hash * 31) + source.codeUnitAt(i)) & 0x7fffffff;
    }

    return hash == 0 ? index + 1 : hash;
  }

  static Future<void> scheduleDailyMedicationReminder({
    required int id,
    required String medicineName,
    required String timeString,
    DateTime? startDate,
    String? body,
  }) async {
    final TimeOfDay parsedTime = _parseTimeString(timeString);
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(
      parsedTime,
      startDate: startDate,
    );

    await _scheduleMedicationReminderAt(
      id: id,
      medicineName: medicineName,
      scheduledDate: scheduledDate,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleMedicationReminderAt({
    required int id,
    required String medicineName,
    required tz.TZDateTime scheduledDate,
    String? body,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Medication Reminder',
      body ?? 'Time to take $medicineName',
      scheduledDate,
      _notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  static Future<List<int>> scheduleMedicationReminders({
    required String medicineName,
    required List<String> times,
    String? body,
    String? userId,
    String? medicationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!await areNotificationsEnabled()) {
      return const <int>[];
    }

    final String? effectiveUserId =
        userId ?? FirebaseAuth.instance.currentUser?.uid;
    final String medicationKey =
        (medicationId != null && medicationId.trim().isNotEmpty)
        ? medicationId.trim()
        : medicineName.trim();

    final List<int> notificationIds = [];

    for (int i = 0; i < times.length; i++) {
      final String time = times[i].trim();

      try {
        if (endDate != null) {
          final scheduledDates = _instancesOfTimeThroughEndDate(
            _parseTimeString(time),
            startDate: startDate,
            endDate: endDate,
          );

          for (final scheduledDate in scheduledDates) {
            final dateStampedTime = '$time-${_dateStamp(scheduledDate)}';
            final int id = effectiveUserId != null
                ? generateStableNotificationId(
                    userId: effectiveUserId,
                    medicationKey: medicationKey,
                    index: i,
                    timeString: dateStampedTime,
                  )
                : generateNotificationId();

            await _scheduleMedicationReminderAt(
              id: id,
              medicineName: medicineName,
              scheduledDate: scheduledDate,
              body: body,
            );

            notificationIds.add(id);
          }
        } else {
          final int id = effectiveUserId != null
              ? generateStableNotificationId(
                  userId: effectiveUserId,
                  medicationKey: medicationKey,
                  index: i,
                  timeString: time,
                )
              : generateNotificationId();

          await scheduleDailyMedicationReminder(
            id: id,
            medicineName: medicineName,
            timeString: time,
            startDate: startDate,
            body: body,
          );

          notificationIds.add(id);
        }
      } catch (e) {
        debugPrint('Failed to schedule reminder for time "$time": $e');
      }
    }

    return notificationIds;
  }

  static Future<void> syncNotificationsForCurrentUser() async {
    await syncNotificationsForUser(FirebaseAuth.instance.currentUser);
  }

  static Future<void> syncNotificationsForUser(User? user) async {
    await syncNotificationsForUserId(user?.uid);
  }

  static Future<void> syncNotificationsForUserId(String? uid) async {
    await cancelAllNotifications();
    if (!await areNotificationsEnabled()) {
      return;
    }

    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      return;
    }

    await restoreNotificationsForUser(normalizedUid);
  }

  static Future<void> restoreNotificationsForUser(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirestorePaths.medicationsCollection(
          FirebaseFirestore.instance,
          uid,
        ).get();

    for (final doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String medicineName = (data['name'] ?? '').toString().trim();
      final List<String> times = List<String>.from(
        data['reminderTimes'] ?? data['times'] ?? const <String>[],
      );
      final bool remindersEnabled = data['remindersEnabled'] != false;

      if (!remindersEnabled || medicineName.isEmpty || times.isEmpty) {
        continue;
      }

      final DateTime? startDate = _parseStoredDate(data['startDate']);
      final DateTime? endDate = _parseStoredDate(data['endDate']);

      final List<int> notificationIds = await scheduleMedicationReminders(
        medicineName: medicineName,
        times: times,
        body: 'Time to take $medicineName',
        userId: uid,
        medicationId: doc.id,
        startDate: startDate,
        endDate: endDate,
      );

      try {
        await doc.reference.update({'notificationIds': notificationIds});
      } catch (e) {
        debugPrint('Failed to update notificationIds for ${doc.id}: $e');
      }

      try {
        final medication = MedicationRecord.fromMap(doc.id, {
          ...data,
          'userId': uid,
          'notificationIds': notificationIds,
        });

        await medicationReminderSyncService.replaceMedicationReminders(
          uid: uid,
          medicationId: doc.id,
          medication: medication,
        );
      } catch (e) {
        debugPrint('Failed to sync reminder docs for ${doc.id}: $e');
      }
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  static Future<void> cancelNotifications(List<dynamic> ids) async {
    for (final dynamic id in ids) {
      final int? parsedId = _toInt(id);
      if (parsedId != null) {
        await _flutterLocalNotificationsPlugin.cancel(parsedId);
      }
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  static Future<bool> areNotificationsEnabled() {
    return notificationPreferencesRepository.loadNotificationsEnabled();
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await notificationPreferencesRepository.setNotificationsEnabled(enabled);

    if (!enabled) {
      await cancelAllNotifications();
      return;
    }

    await syncNotificationsForCurrentUser();
  }

  static TimeOfDay _parseTimeString(String timeString) {
    final parsedTime = LocalizedTimeParser.parse(timeString);

    return TimeOfDay(hour: parsedTime.hour, minute: parsedTime.minute);
  }

  static tz.TZDateTime _nextInstanceOfTime(
    TimeOfDay time, {
    DateTime? startDate,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final DateTime baseDate = startDate ?? now;
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      baseDate.year,
      baseDate.month,
      baseDate.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }

    return scheduledDate;
  }

  static List<tz.TZDateTime> _instancesOfTimeThroughEndDate(
    TimeOfDay time, {
    DateTime? startDate,
    required DateTime endDate,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final DateTime activeStart = startDate != null && startDate.isAfter(now)
        ? startDate
        : now;
    DateTime cursor = DateTime(
      activeStart.year,
      activeStart.month,
      activeStart.day,
    );
    final DateTime lastDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (lastDate.isBefore(cursor)) {
      return const <tz.TZDateTime>[];
    }

    final scheduledDates = <tz.TZDateTime>[];

    while (!cursor.isAfter(lastDate)) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        cursor.year,
        cursor.month,
        cursor.day,
        time.hour,
        time.minute,
      );

      if (!scheduledDate.isBefore(now)) {
        scheduledDates.add(scheduledDate);
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    return scheduledDates;
  }

  static String _dateStamp(tz.TZDateTime value) {
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseStoredDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<void> printPendingNotifications() async {
    final pending = await _flutterLocalNotificationsPlugin
        .pendingNotificationRequests();

    debugPrint('Pending count: ${pending.length}');

    for (final item in pending) {
      debugPrint(
        'Pending -> id: ${item.id}, title: ${item.title}, body: ${item.body}',
      );
    }
  }
}
