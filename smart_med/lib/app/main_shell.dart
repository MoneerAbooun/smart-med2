import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/home/presentation/home_page.dart';
import 'package:smart_med/features/profile/profile.dart';
import 'package:smart_med/features/settings/presentation/settings_page.dart';

class MainShell extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  const MainShell({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _profileRefreshToken = 0;

  void goToProfileTab() {
    setState(() {
      _currentIndex = 1;
      _profileRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [
      const HomePage(),
      ProfilePage(key: ValueKey(_profileRefreshToken)),
      SettingsPage(
        onEditProfileTap: goToProfileTab,
        isDark: widget.isDark,
        onThemeChanged: widget.onThemeChanged,
        currentLocale: widget.currentLocale,
        onLocaleChanged: widget.onLocaleChanged,
      ),
    ];

    return SafeArea(
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: .18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (value) {
                  setState(() {
                    _currentIndex = value;
                    if (value == 1) {
                      _profileRefreshToken++;
                    }
                  });
                },
                backgroundColor: colorScheme.surface,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: colorScheme.onSurfaceVariant,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined),
                    label: context.l10n.text('nav.home'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline),
                    label: context.l10n.text('nav.profile'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    label: context.l10n.text('nav.settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
