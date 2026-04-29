import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 7, 207, 221),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF0394F4),
          secondary: const Color(0xFF7CCBFF),
          surface: const Color(0xFFF9FCFF),
          onPrimary: Colors.white,
          onSurface: const Color(0xFF1A2A36),
          primaryContainer: const Color(0xFFDDEEFF),
          onPrimaryContainer: const Color(0xFF1F5E99),
          secondaryContainer: const Color(0xFFEAF4FF),
          onSecondaryContainer: const Color(0xFF1A2A36),
          surfaceContainerHighest: const Color(0xFFFFFFFF),
          outlineVariant: const Color(0xFFD7E6F5),
        ),

    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF1A2A36),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 4,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      hintStyle: const TextStyle(color: Color(0xFF6B7C87)),
      prefixIconColor: const Color(0xFF4B7EAA),
      suffixIconColor: const Color(0xFF4B7EAA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB7C4D1)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0394F4), width: 1.8),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E8CD0),
        foregroundColor: Colors.white,
        minimumSize: const Size(130, 48),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2E8CD0),
        side: const BorderSide(color: Color(0xFFB7D5F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: const Color(0xFF2E8CD0)),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2E8CD0),
      foregroundColor: Colors.white,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFF1A2A36),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Color(0xFF1A2A36), fontSize: 15),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB6FF),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF4DB6FF),
          secondary: const Color(0xFF7FD0FF),
          surface: const Color(0xFF1A2733),
          onPrimary: const Color(0xFF08131A),
          onSurface: Colors.white,
          primaryContainer: const Color(0xFF1E4B69),
          onPrimaryContainer: Colors.white,
          secondaryContainer: const Color(0xFF203544),
          onSecondaryContainer: Colors.white,
          surfaceContainerHighest: const Color(0xFF223241),
          outlineVariant: const Color(0xFF506373),
        ),

    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF1A2733).withValues(alpha: 0.94),
      elevation: 5,
      shadowColor: Colors.black54,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF223241),
      hintStyle: const TextStyle(color: Color(0xFF9DB2BF)),
      prefixIconColor: const Color(0xFF8FD0FF),
      suffixIconColor: const Color(0xFF8FD0FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF506373)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4DB6FF), width: 1.8),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E8CD0),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size(130, 48),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8FD0FF),
        side: const BorderSide(color: Color(0xFF506373)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: const Color(0xFF8FD0FF)),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2E8CD0),
      foregroundColor: Colors.white,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
    ),
  );
}
