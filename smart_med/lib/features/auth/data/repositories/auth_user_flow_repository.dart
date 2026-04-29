import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/features/auth/data/repositories/auth_repository.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthUserFlowRepository {
  AuthUserFlowRepository({
    AuthRepository? authRepo,
    ProfileRepository? profileRepo,
  }) : _authRepository = authRepo ?? authRepository,
       _profileRepository = profileRepo ?? profileRepository;

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  Future<User> signUpAndCreateProfile({
    required String email,
    required String password,
    required String username,
    required int age,
    List<String> chronicDiseases = const <String>[],
    List<String> drugAllergies = const <String>[],
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanedUsername = username.trim();

    final credential = await _authRepository.createAccount(
      email: normalizedEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw const AuthFlowException(
        'Account creation finished without a signed-in Firebase user.',
      );
    }

    await _tryUpdateDisplayName(user: user, username: cleanedUsername);

    try {
      await _profileRepository.createUserProfile(
        uid: user.uid,
        username: cleanedUsername,
        age: age,
        email: user.email ?? normalizedEmail,
        chronicDiseases: chronicDiseases,
        drugAllergies: drugAllergies,
        hasCompletedQuickProfileSetup: false,
      );

      return _authRepository.currentUser ?? user;
    } on ProfileRepositoryException catch (e) {
      await _rollbackIncompleteSignup(user);
      throw AuthFlowException(e.message);
    } catch (_) {
      await _rollbackIncompleteSignup(user);
      throw const AuthFlowException(
        'We created the account, but failed to save the Firestore profile.',
      );
    }
  }

  Future<User> signInAndEnsureProfile({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _authRepository.signIn(
      email: normalizedEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      await _authRepository.signOut();
      throw const AuthFlowException(
        'Login finished without a signed-in Firebase user.',
      );
    }

    try {
      await ensureProfileForUser(user, fallbackEmail: normalizedEmail);
      return user;
    } on ProfileRepositoryException catch (e) {
      await _authRepository.signOut();
      throw AuthFlowException(e.message);
    } catch (_) {
      await _authRepository.signOut();
      throw const AuthFlowException(
        'Login succeeded, but loading the Firestore profile failed.',
      );
    }
  }

  Future<UserProfileRecord> ensureCurrentUserProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw const AuthFlowException('No signed-in Firebase user was found.');
    }

    return ensureProfileForUser(user);
  }

  Future<UserProfileRecord> ensureProfileForUser(
    User user, {
    String? fallbackEmail,
  }) async {
    return _profileRepository.ensureUserProfile(
      uid: user.uid,
      email: user.email ?? fallbackEmail ?? '',
      username: user.displayName,
    );
  }

  Future<void> _tryUpdateDisplayName({
    required User user,
    required String username,
  }) async {
    if (username.isEmpty || user.displayName == username) {
      return;
    }

    try {
      await user.updateDisplayName(username);
      await user.reload();
    } catch (_) {
      // Keep signup resilient even if Firebase Auth profile metadata lags.
    }
  }

  Future<void> _rollbackIncompleteSignup(User user) async {
    try {
      await user.delete();
      return;
    } catch (_) {
      // Fall back to sign-out so the app does not keep a broken session alive.
    }

    try {
      await _authRepository.signOut();
    } catch (_) {}
  }
}

final AuthUserFlowRepository authUserFlowRepository = AuthUserFlowRepository();
