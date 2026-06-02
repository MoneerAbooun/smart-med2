import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, error, warning }

class AppSnackBar {
  const AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarType? type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snackBarType = type ?? _inferType(message);
    final accentColor = _accentColor(snackBarType, colorScheme);
    final icon = _icon(snackBarType);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF123247)
                : const Color(0xFFBFE3FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
                ),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static AppSnackBarType _inferType(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('success') ||
        normalized.contains('saved') ||
        normalized.contains('deleted') ||
        normalized.contains('enabled') ||
        normalized.contains('synced') ||
        normalized.contains('marked as')) {
      return AppSnackBarType.success;
    }

    if (normalized.contains('failed') ||
        normalized.contains('invalid') ||
        normalized.contains('error') ||
        normalized.contains('denied') ||
        normalized.contains('unable') ||
        normalized.contains('could not') ||
        normalized.contains('went wrong')) {
      return AppSnackBarType.error;
    }

    if (normalized.contains('please') ||
        normalized.contains('must') ||
        normalized.contains('maximum') ||
        normalized.contains('already') ||
        normalized.contains('warning')) {
      return AppSnackBarType.warning;
    }

    return AppSnackBarType.info;
  }

  static Color _accentColor(AppSnackBarType type, ColorScheme colorScheme) {
    switch (type) {
      case AppSnackBarType.success:
        return const Color(0xFF20A979);
      case AppSnackBarType.error:
        return const Color(0xFFE15656);
      case AppSnackBarType.warning:
        return const Color(0xFFF2A93B);
      case AppSnackBarType.info:
        return colorScheme.primary;
    }
  }

  static IconData _icon(AppSnackBarType type) {
    switch (type) {
      case AppSnackBarType.success:
        return Icons.check_circle_rounded;
      case AppSnackBarType.error:
        return Icons.error_rounded;
      case AppSnackBarType.warning:
        return Icons.warning_amber_rounded;
      case AppSnackBarType.info:
        return Icons.info_rounded;
    }
  }
}
