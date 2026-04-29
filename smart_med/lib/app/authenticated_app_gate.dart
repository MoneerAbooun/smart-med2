import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  });

  final User user;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

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

  String _bootstrapErrorMessage(Object error) {
    if (error is ProfileRepositoryException) {
      return error.message;
    }

    if (error is AuthFlowException) {
      return error.message;
    }

    return 'Retry to create or repair the user document, or sign out to try again later.';
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
    return FutureBuilder<UserProfileRecord>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingScaffold('Preparing your profile...');
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
                        'We could not finish loading your Firestore profile.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bootstrapErrorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _retryBootstrap,
                          child: const Text('Retry'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          child: const Text('Sign Out'),
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
              return _buildLoadingScaffold('Loading your Smart Med tools...');
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
                );
              },
            );
          },
        );
      },
    );
  }
}
