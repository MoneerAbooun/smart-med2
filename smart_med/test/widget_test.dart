import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/app/main_app.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(
        initialThemeMode: ThemeMode.light,
        authStateChanges: const Stream.empty(),
        syncNotificationsForUser: (_) async {},
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
