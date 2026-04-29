import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/features/onboarding/onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingPreferencesRepository', () {
    late OnboardingPreferencesRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = OnboardingPreferencesRepository();
    });

    test('shows onboarding by default for a new user', () async {
      final shouldShow = await repository.shouldShowOnboardingForUser('user-1');

      expect(shouldShow, isTrue);
    });

    test('stores onboarding completion per user', () async {
      await repository.markOnboardingCompleted('user-1');

      final firstUserShouldShow = await repository.shouldShowOnboardingForUser(
        'user-1',
      );
      final secondUserShouldShow = await repository.shouldShowOnboardingForUser(
        'user-2',
      );

      expect(firstUserShouldShow, isFalse);
      expect(secondUserShouldShow, isTrue);
    });
  });
}
