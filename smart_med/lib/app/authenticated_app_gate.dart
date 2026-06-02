import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/main_shell.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/auth/auth.dart';
import 'package:smart_med/features/onboarding/onboarding.dart';
import 'package:smart_med/features/profile/profile.dart';

class AuthenticatedAppGate extends StatefulWidget {
  const AuthenticatedAppGate({
    super.key,
    required this.user,
    required this.isDark,
    required this.onThemeChanged,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  final User user;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AuthenticatedAppGate> createState() => _AuthenticatedAppGateState();
}

class _AuthenticatedAppGateState extends State<AuthenticatedAppGate> {
  late Future<UserProfileRecord> _bootstrapFuture;
  late Future<bool> _shouldShowOnboardingFuture;
  late Stream<UserProfileRecord?> _profileStream;
  bool? _hasCompletedQuickProfileSetupOverride;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
    _shouldShowOnboardingFuture = _loadOnboardingDecision();
    _profileStream = _watchProfile();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAppGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.uid != widget.user.uid) {
      _bootstrapFuture = _bootstrap();
      _shouldShowOnboardingFuture = _loadOnboardingDecision();
      _profileStream = _watchProfile();
      _hasCompletedQuickProfileSetupOverride = null;
    }
  }

  Future<void> _retryBootstrap() async {
    setState(() {
      _bootstrapFuture = _bootstrap();
      _profileStream = _watchProfile();
    });
  }

  Future<void> _signOut() async {
    await authRepository.signOut();
  }

  Future<bool> _loadOnboardingDecision() {
    return onboardingPreferencesRepository.shouldShowOnboardingForUser(
      widget.user.uid,
    );
  }

  void _finishOnboarding() {
    setState(() {
      _shouldShowOnboardingFuture = Future<bool>.value(false);
    });
  }

  void _finishQuickProfileSetup() {
    setState(() {
      _hasCompletedQuickProfileSetupOverride = true;
    });
  }

  Future<UserProfileRecord> _bootstrap() {
    return authUserFlowRepository.ensureProfileForUser(widget.user);
  }

  Stream<UserProfileRecord?> _watchProfile() {
    return profileRepository.watchProfile(uid: widget.user.uid);
  }

  String _bootstrapErrorMessage(BuildContext context, Object error) {
    if (error is ProfileRepositoryException) {
      return error.message;
    }

    if (error is AuthFlowException) {
      return error.message;
    }

    return context.l10n.text('gate.profileError.retry');
  }

  Widget _buildLoadingScaffold(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<UserProfileRecord>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingScaffold(l10n.text('gate.loadingProfile'));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIconBadge(
                        icon: Icons.error_outline,
                        accentColor: Color(0xFFD56262),
                        size: 60,
                        iconSize: 30,
                        borderRadius: 20,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.text('gate.profileError.title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bootstrapErrorMessage(context, snapshot.error!),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _retryBootstrap,
                          child: Text(l10n.text('common.retry')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          child: Text(l10n.text('common.signOut')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return FutureBuilder<bool>(
          future: _shouldShowOnboardingFuture,
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState != ConnectionState.done) {
              return _buildLoadingScaffold(l10n.text('gate.loadingTools'));
            }

            if (onboardingSnapshot.data ?? false) {
              return OnboardingPage(
                userId: widget.user.uid,
                onFinished: _finishOnboarding,
              );
            }

            return StreamBuilder<UserProfileRecord?>(
              stream: _profileStream,
              initialData: snapshot.data,
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data ?? snapshot.data!;
                final hasCompletedQuickProfileSetup =
                    _hasCompletedQuickProfileSetupOverride ??
                    profile.hasCompletedQuickProfileSetup;

                if (!hasCompletedQuickProfileSetup) {
                  return QuickProfileSetupPage(
                    profile: profile,
                    onFinished: _finishQuickProfileSetup,
                  );
                }

                return MainShell(
                  isDark: widget.isDark,
                  onThemeChanged: widget.onThemeChanged,
                  currentLocale: widget.currentLocale,
                  onLocaleChanged: widget.onLocaleChanged,
                );
              },
            );
          },
        );
      },
    );
  }
}
