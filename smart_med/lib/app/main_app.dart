import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/app/authenticated_app_gate.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/theme/app_theme.dart';
import 'package:smart_med/app/widgets/app_page_background.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/auth/auth.dart';

class MainApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final Locale initialLocale;
  final Stream<User?>? authStateChanges;
  final User? initialUser;
  final Future<void> Function(User? user)? syncNotificationsForUser;

  const MainApp({
    super.key,
    required this.initialThemeMode,
    this.initialLocale = const Locale('en'),
    this.authStateChanges,
    this.initialUser,
    this.syncNotificationsForUser,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late ThemeMode _themeMode;
  late Locale _locale;
  bool _notificationPermissionRequested = false;
  StreamSubscription<User?>? _authSubscription;
  String? _lastQueuedNotificationUserId;
  String? _lastAppliedNotificationUserId;
  Future<void> _notificationSyncQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _locale = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == widget.initialLocale.languageCode,
    )
        ? Locale(widget.initialLocale.languageCode)
        : const Locale('en');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionOnce();
    });

    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _enqueueNotificationSync(_currentUser);

    _authSubscription = _authStateChanges.listen((user) {
      _enqueueNotificationSync(user);
    });
  }

  User? get _currentUser {
    if (widget.authStateChanges != null) {
      return widget.initialUser;
    }

    return FirebaseAuth.instance.currentUser;
  }

  Stream<User?> get _authStateChanges {
    return widget.authStateChanges ?? FirebaseAuth.instance.authStateChanges();
  }

  void _enqueueNotificationSync(User? user) {
    final String? userId = user?.uid;

    if (userId == _lastQueuedNotificationUserId) {
      return;
    }

    _lastQueuedNotificationUserId = userId;
    _notificationSyncQueue = _notificationSyncQueue
        .then((_) => _syncNotificationsForUser(user))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Failed to sync notifications for auth change: $error');
        });
  }

  Future<void> _syncNotificationsForUser(User? user) async {
    final String? userId = user?.uid;

    if (userId == _lastAppliedNotificationUserId) {
      return;
    }

    _lastAppliedNotificationUserId = userId;
    final syncNotificationsForUser = widget.syncNotificationsForUser;

    if (syncNotificationsForUser != null) {
      await syncNotificationsForUser(user);
      return;
    }

    await NotificationService.syncNotificationsForUser(user);
  }

  Future<void> _requestNotificationPermissionOnce() async {
    if (_notificationPermissionRequested) {
      return;
    }

    _notificationPermissionRequested = true;
    await NotificationService.requestPermission();
  }

  Future<void> _changeTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _changeLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);

    setState(() {
      _locale = Locale(locale.languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return AppPageBackground(child: child ?? const SizedBox.shrink());
      },
      home: StreamBuilder<User?>(
        stream: _authStateChanges,
        initialData: _currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AuthenticatedAppGate(
              key: ValueKey(snapshot.data!.uid),
              user: snapshot.data!,
              isDark: _themeMode == ThemeMode.dark,
              onThemeChanged: _changeTheme,
              currentLocale: _locale,
              onLocaleChanged: _changeLocale,
            );
          }

          return const LoginPage();
        },
      ),
    );
  }
}
