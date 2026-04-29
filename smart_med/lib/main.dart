import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/app/main_app.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('isDark') ?? false;

  await NotificationService.init();

  runApp(MainApp(initialThemeMode: isDark ? ThemeMode.dark : ThemeMode.light));
}
