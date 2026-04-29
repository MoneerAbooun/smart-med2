import 'package:flutter/material.dart';
import 'package:smart_med/features/onboarding/data/onboarding_preferences_repository.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';

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
      title: 'Quick Add Medications',
      description:
          'Save a medicine in a few taps, attach a photo when helpful, and keep everything organized in one place.',
      accent: Color(0xFF2E7D6F),
    ),
    _OnboardingStep(
      icon: Icons.compare_arrows_outlined,
      title: 'Check Drug Interactions',
      description:
          'Compare medicines before taking them together so you can catch risky combinations and warnings early.',
      accent: Color(0xFFD47B2E),
    ),
    _OnboardingStep(
      icon: Icons.photo_camera_back_outlined,
      title: 'Search by Image',
      description:
          'Use the camera or gallery to identify medicine packaging, labels, or pills faster when typing is not convenient.',
      accent: Color(0xFF3B6FD8),
    ),
    _OnboardingStep(
      icon: Icons.notifications_active_outlined,
      title: 'Get Reminders',
      description:
          'Add reminder times while saving medications so Smart Med can help you stay on schedule every day.',
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Smart Med Tour',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : _finishOnboarding,
                    child: const Text('Skip'),
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
                              step.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.description,
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
                'Screen ${_currentIndex + 1} of ${_steps.length}',
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
                              ? 'Get Started'
                              : 'Next',
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
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
}
