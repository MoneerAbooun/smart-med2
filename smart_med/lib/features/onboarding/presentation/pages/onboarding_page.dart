import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/onboarding/data/onboarding_preferences_repository.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.userId,
    required this.onFinished,
  });

  final String userId;
  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<_OnboardingStep> _steps = <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.playlist_add_circle_outlined,
      titleKey: 'onboarding.step.add.title',
      descriptionKey: 'onboarding.step.add.description',
      accent: Color(0xFF2E7D6F),
    ),
    _OnboardingStep(
      icon: Icons.compare_arrows_outlined,
      titleKey: 'onboarding.step.interactions.title',
      descriptionKey: 'onboarding.step.interactions.description',
      accent: Color(0xFFD47B2E),
    ),
    _OnboardingStep(
      icon: Icons.health_and_safety_outlined,
      titleKey: 'onboarding.step.profile.title',
      descriptionKey: 'onboarding.step.profile.description',
      accent: Color(0xFF2F8F46),
    ),
    _OnboardingStep(
      icon: Icons.photo_camera_back_outlined,
      titleKey: 'onboarding.step.photo.title',
      descriptionKey: 'onboarding.step.photo.description',
      accent: Color(0xFF3B6FD8),
    ),
    _OnboardingStep(
      icon: Icons.notifications_active_outlined,
      titleKey: 'onboarding.step.reminders.title',
      descriptionKey: 'onboarding.step.reminders.description',
      accent: Color(0xFF8A4FE0),
    ),
  ];

  final PageController _pageController = PageController();

  int _currentIndex = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_currentIndex == _steps.length - 1) {
      await _finishOnboarding();
      return;
    }

    await _pageController.animateToPage(
      _currentIndex + 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await onboardingPreferencesRepository.markOnboardingCompleted(
      widget.userId,
    );

    if (!mounted) {
      return;
    }

    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    l10n.text('onboarding.title'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : _finishOnboarding,
                    child: Text(l10n.text('onboarding.skip')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final step = _steps[index];

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            AppIconBadge(
                              icon: step.icon,
                              accentColor: step.accent,
                              size: 104,
                              iconSize: 54,
                              borderRadius: 30,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              l10n.text(step.titleKey),
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.text(step.descriptionKey),
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_steps.length, (int index) {
                  final bool isActive = index == _currentIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: isActive ? 28 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.format('onboarding.step', {
                  'current': (_currentIndex + 1).toString(),
                  'total': _steps.length.toString(),
                }),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          _currentIndex == _steps.length - 1
                              ? l10n.text('onboarding.getStarted')
                              : l10n.text('onboarding.next'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.accent,
  });

  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color accent;
}
