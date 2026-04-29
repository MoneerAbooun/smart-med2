import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferencesRepository {
  static const String _completedKeyPrefix = 'onboarding_completed_';

  Future<bool> shouldShowOnboardingForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_completedKeyPrefix + userId) ?? false);
  }

  Future<void> markOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKeyPrefix + userId, true);
  }
}

final OnboardingPreferencesRepository onboardingPreferencesRepository =
    OnboardingPreferencesRepository();
