import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/auth/auth.dart';
import 'package:smart_med/features/medications/medications.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onEditProfileTap;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  const SettingsPage({
    super.key,
    required this.onEditProfileTap,
    required this.isDark,
    required this.onThemeChanged,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notificationsAreEnabled =
        await NotificationService.areNotificationsEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      notificationsEnabled = notificationsAreEnabled;
    });
  }

  Widget buildSettingItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: AppIconBadge(
          icon: icon,
          accentColor: colorScheme.primary,
          size: 42,
          iconSize: 20,
          borderRadius: 14,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
        onTap: onTap,
      ),
    );
  }

  void showSimpleDialogBox(String title, String content) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.text('common.ok')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.text('settings.title'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 10, end: 8),
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: l10n.text('home.action.medicines'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicationListPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 25,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          l10n.text('settings.title'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      buildSettingItem(
                        icon: Icons.person_outline,
                        title: l10n.text('settings.editProfile'),
                        onTap: widget.onEditProfileTap,
                      ),
                      buildSettingItem(
                        icon: widget.isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: l10n.text('settings.darkMode'),
                        trailing: Switch(
                          value: widget.isDark,
                          onChanged: widget.onThemeChanged,
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.notifications_none,
                        title: l10n.text('settings.notifications'),
                        trailing: Switch(
                          value: notificationsEnabled,
                          onChanged: (value) async {
                            if (value) {
                              final granted =
                                  await NotificationService.requestPermission();

                              if (!granted) {
                                if (!context.mounted) return;

                                AppSnackBar.show(
                                  context,
                                  l10n.text('settings.notifications.blocked'),
                                  type: AppSnackBarType.error,
                                );

                                setState(() {
                                  notificationsEnabled = false;
                                });
                                return;
                              }

                              await NotificationService.setNotificationsEnabled(
                                true,
                              );
                              await NotificationService.showInstantNotification(
                                title: l10n.text('app.name'),
                                body: l10n.text('settings.notifications.ready'),
                              );

                              if (!context.mounted) return;

                              setState(() {
                                notificationsEnabled = true;
                              });

                              AppSnackBar.show(
                                context,
                                l10n.text('settings.notifications.on'),
                                type: AppSnackBarType.success,
                              );
                            } else {
                              await NotificationService.setNotificationsEnabled(
                                false,
                              );

                              setState(() {
                                notificationsEnabled = false;
                              });

                              if (!context.mounted) return;

                              AppSnackBar.show(
                                context,
                                l10n.text('settings.notifications.off'),
                                type: AppSnackBarType.info,
                              );
                            }
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.language,
                        title: l10n.text('settings.language'),
                        trailing: DropdownButton<String>(
                          value: widget.currentLocale.languageCode,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(l10n.text('common.english')),
                            ),
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text(l10n.text('common.arabic')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            widget.onLocaleChanged(Locale(value));
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.info_outline,
                        title: l10n.text('settings.about'),
                        onTap: () {
                          showSimpleDialogBox(
                            l10n.text('settings.about'),
                            l10n.text('settings.about.body'),
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.contact_mail_outlined,
                        title: l10n.text('settings.contact'),
                        onTap: () {
                          showSimpleDialogBox(
                            l10n.text('settings.contact'),
                            l10n.text('settings.contact.body'),
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.help_outline,
                        title: l10n.text('settings.help'),
                        onTap: () {
                          showSimpleDialogBox(
                            l10n.text('settings.help'),
                            l10n.text('settings.help.body'),
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.system_update_alt,
                        title: l10n.text('settings.version'),
                        onTap: () {
                          showSimpleDialogBox(
                            l10n.text('settings.version'),
                            l10n.text('settings.version.body'),
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.logout,
                        title: l10n.text('common.signOut'),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.text('settings.signOut.title')),
                              content: Text(l10n.text('settings.signOut.body')),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(l10n.text('common.cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(l10n.text('common.signOut')),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await authRepository.signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
