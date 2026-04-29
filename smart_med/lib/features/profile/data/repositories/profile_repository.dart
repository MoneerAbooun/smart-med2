import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';
import 'package:smart_med/features/allergies/data/allergy_repository.dart';
import 'package:smart_med/features/allergies/data/models/allergy_record.dart';
import 'package:smart_med/features/medical_conditions/data/medical_condition_repository.dart';
import 'package:smart_med/features/medical_conditions/data/models/medical_condition_record.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
    AllergyRepository? allergyRepository,
    MedicalConditionRepository? medicalConditionRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _allergyRepository =
           allergyRepository ?? AllergyRepository(firestore: firestore),
       _medicalConditionRepository =
           medicalConditionRepository ??
           MedicalConditionRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AllergyRepository _allergyRepository;
  final MedicalConditionRepository _medicalConditionRepository;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return FirestorePaths.userDoc(_firestore, uid);
  }

  DocumentReference<Map<String, dynamic>> _legacyUserDoc(String uid) {
    return FirestorePaths.legacyUserDoc(_firestore, uid);
  }

  String _normalizedEmail(String email) {
    return email.trim().toLowerCase();
  }

  List<String> _normalizedStringList(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final normalizedValue = value.trim();
      if (normalizedValue.isEmpty) {
        continue;
      }

      final lookupKey = normalizedValue.toLowerCase();
      if (seen.add(lookupKey)) {
        result.add(normalizedValue);
      }
    }

    return result;
  }

  String _normalizedBiologicalSex(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'female' ? 'female' : 'male';
  }

  String _firestoreError(String action, FirebaseException exception) {
    final code = exception.code.trim();
    if (code.isEmpty) {
      return 'Failed to $action.';
    }

    return 'Failed to $action (${exception.code}).';
  }

  String _fallbackDisplayName({
    required String email,
    String? username,
    String? existingDisplayName,
  }) {
    final candidates = [
      existingDisplayName,
      username,
      email.contains('@') ? email.split('@').first : email,
      'Smart Med User',
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'Smart Med User';
  }

  UserProfileRecord _buildProfile({
    required String uid,
    required String email,
    String? username,
    int? age,
    Map<String, dynamic>? medicalInfo,
    List<String> chronicDiseases = const <String>[],
    List<String> drugAllergies = const <String>[],
    String? photoUrl,
    bool hasCompletedQuickProfileSetup = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final normalizedEmail = _normalizedEmail(email);
    final normalizedDiseases = _normalizedStringList(chronicDiseases);
    final normalizedAllergies = _normalizedStringList(drugAllergies);
    final biologicalSex = _normalizedBiologicalSex(
      medicalInfo?['biologicalSex'],
    );
    final isFemale = biologicalSex == 'female';

    return UserProfileRecord(
      authUid: uid,
      email: normalizedEmail,
      displayName: _fallbackDisplayName(
        email: normalizedEmail,
        username: username,
      ),
      photoUrl: photoUrl,
      age: age,
      biologicalSex: biologicalSex,
      weightKg: FirestoreValueParser.doubleOrNull(medicalInfo?['weightKg']),
      heightCm: FirestoreValueParser.doubleOrNull(medicalInfo?['heightCm']),
      systolicPressure: FirestoreValueParser.intOrNull(
        medicalInfo?['systolicPressure'],
      ),
      diastolicPressure: FirestoreValueParser.intOrNull(
        medicalInfo?['diastolicPressure'],
      ),
      bloodGlucose: FirestoreValueParser.doubleOrNull(
        medicalInfo?['bloodGlucose'],
      ),
      isPregnant: isFemale && medicalInfo?['isPregnant'] == true,
      isBreastfeeding: isFemale && medicalInfo?['isBreastfeeding'] == true,
      allergyNames: normalizedAllergies,
      medicalConditionNames: normalizedDiseases,
      hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  UserProfileRecord _repairProfile(
    UserProfileRecord current, {
    required String normalizedEmail,
    String? username,
    int? age,
    List<String>? chronicDiseases,
    List<String>? drugAllergies,
    bool hasCompletedQuickProfileSetup = true,
  }) {
    final fallbackEmail = current.email.trim().isNotEmpty
        ? current.email
        : normalizedEmail;

    return UserProfileRecord(
      authUid: current.authUid,
      email: fallbackEmail,
      displayName: _fallbackDisplayName(
        email: fallbackEmail,
        username: username,
        existingDisplayName: current.displayName,
      ),
      photoUrl: current.photoUrl,
      age: current.age ?? age,
      biologicalSex: current.biologicalSex ?? 'male',
      weightKg: current.weightKg,
      heightCm: current.heightCm,
      systolicPressure: current.systolicPressure,
      diastolicPressure: current.diastolicPressure,
      bloodGlucose: current.bloodGlucose,
      isPregnant: current.biologicalSex == 'female'
          ? current.isPregnant
          : false,
      isBreastfeeding: current.biologicalSex == 'female'
          ? current.isBreastfeeding
          : false,
      allergyNames: current.allergyNames.isNotEmpty
          ? _normalizedStringList(current.allergyNames)
          : _normalizedStringList(drugAllergies ?? const <String>[]),
      medicalConditionNames: current.medicalConditionNames.isNotEmpty
          ? _normalizedStringList(current.medicalConditionNames)
          : _normalizedStringList(chronicDiseases ?? const <String>[]),
      hasCompletedQuickProfileSetup:
          current.hasCompletedQuickProfileSetup &&
          hasCompletedQuickProfileSetup,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
  }

  bool _needsRepair(
    UserProfileRecord current, {
    required String normalizedEmail,
    String? username,
    int? age,
    List<String>? chronicDiseases,
    List<String>? drugAllergies,
    bool hasCompletedQuickProfileSetup = true,
  }) {
    final normalizedCurrentAllergies = _normalizedStringList(
      current.allergyNames,
    );
    final normalizedCurrentConditions = _normalizedStringList(
      current.medicalConditionNames,
    );
    final normalizedIncomingAllergies = _normalizedStringList(
      drugAllergies ?? const <String>[],
    );
    final normalizedIncomingConditions = _normalizedStringList(
      chronicDiseases ?? const <String>[],
    );

    return (current.email.trim().isEmpty && normalizedEmail.isNotEmpty) ||
        current.displayName.trim().isEmpty ||
        (current.age == null && age != null) ||
        (current.hasCompletedQuickProfileSetup &&
            !hasCompletedQuickProfileSetup) ||
        normalizedCurrentAllergies.length != current.allergyNames.length ||
        normalizedCurrentConditions.length !=
            current.medicalConditionNames.length ||
        (normalizedCurrentAllergies.isEmpty &&
            normalizedIncomingAllergies.isNotEmpty) ||
        (normalizedCurrentConditions.isEmpty &&
            normalizedIncomingConditions.isNotEmpty);
  }

  Future<UserProfileRecord> _hydrateProfile({
    required String uid,
    required Map<String, dynamic> data,
    required bool includeNestedCollections,
  }) async {
    final baseProfile = UserProfileRecord.fromMap(uid, data);

    if (!includeNestedCollections) {
      return baseProfile;
    }

    try {
      final allergies = await _allergyRepository.listAllergies(uid: uid);
      final conditions = await _medicalConditionRepository.listConditions(
        uid: uid,
      );

      return UserProfileRecord(
        authUid: baseProfile.authUid,
        email: baseProfile.email,
        displayName: baseProfile.displayName,
        photoUrl: baseProfile.photoUrl,
        age: baseProfile.age,
        biologicalSex: baseProfile.biologicalSex,
        weightKg: baseProfile.weightKg,
        heightCm: baseProfile.heightCm,
        systolicPressure: baseProfile.systolicPressure,
        diastolicPressure: baseProfile.diastolicPressure,
        bloodGlucose: baseProfile.bloodGlucose,
        isPregnant: baseProfile.isPregnant,
        isBreastfeeding: baseProfile.isBreastfeeding,
        allergyNames: allergies.isNotEmpty
            ? allergies.map((item) => item.name).toList(growable: false)
            : baseProfile.allergyNames,
        medicalConditionNames: conditions.isNotEmpty
            ? conditions.map((item) => item.name).toList(growable: false)
            : baseProfile.medicalConditionNames,
        hasCompletedQuickProfileSetup:
            baseProfile.hasCompletedQuickProfileSetup,
        createdAt: baseProfile.createdAt,
        updatedAt: baseProfile.updatedAt,
      );
    } on FirebaseException {
      // Fall back to the top-level document so profile bootstrap still succeeds
      // when legacy nested collections are absent or temporarily unavailable.
      return baseProfile;
    }
  }

  Future<void> saveProfile(UserProfileRecord profile) async {
    final payload = profile.toMap();
    payload['authUid'] = profile.authUid;
    payload['updatedAt'] = FieldValue.serverTimestamp();

    try {
      final existing = await _userDoc(profile.authUid).get();
      payload['createdAt'] = existing.exists
          ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
          : (profile.createdAt ?? FieldValue.serverTimestamp());

      await _userDoc(profile.authUid).set(payload, SetOptions(merge: true));

      await _allergyRepository.replaceAllergies(
        uid: profile.authUid,
        allergies: profile.allergyNames
            .map(
              (name) => AllergyRecord(
                userId: profile.authUid,
                name: name,
                type: 'drug',
              ),
            )
            .toList(growable: false),
      );

      await _medicalConditionRepository.replaceConditions(
        uid: profile.authUid,
        conditions: profile.medicalConditionNames
            .map(
              (name) => MedicalConditionRecord(
                userId: profile.authUid,
                name: name,
                status: 'active',
              ),
            )
            .toList(growable: false),
      );
    } on FirebaseException catch (e) {
      throw ProfileRepositoryException(
        _firestoreError('save the Firestore user profile', e),
      );
    }
  }

  Future<UserProfileRecord?> fetchProfile({required String uid}) async {
    try {
      final doc = await _userDoc(uid).get();
      if (doc.exists) {
        return _hydrateProfile(
          uid: uid,
          data: doc.data()!,
          includeNestedCollections: true,
        );
      }

      final legacyDoc = await _legacyUserDoc(uid).get();
      if (!legacyDoc.exists) {
        return null;
      }

      return _hydrateProfile(
        uid: uid,
        data: legacyDoc.data()!,
        includeNestedCollections: false,
      );
    } on FirebaseException catch (e) {
      throw ProfileRepositoryException(
        _firestoreError('load the Firestore user profile', e),
      );
    }
  }

  Stream<UserProfileRecord?> watchProfile({required String uid}) async* {
    try {
      await for (final snapshot in _userDoc(uid).snapshots()) {
        if (snapshot.exists && snapshot.data() != null) {
          yield await _hydrateProfile(
            uid: uid,
            data: snapshot.data()!,
            includeNestedCollections: true,
          );
          continue;
        }

        final legacySnapshot = await _legacyUserDoc(uid).get();
        if (!legacySnapshot.exists || legacySnapshot.data() == null) {
          yield null;
          continue;
        }

        yield await _hydrateProfile(
          uid: uid,
          data: legacySnapshot.data()!,
          includeNestedCollections: false,
        );
      }
    } on FirebaseException catch (e) {
      throw ProfileRepositoryException(
        _firestoreError('watch the Firestore user profile', e),
      );
    }
  }

  Future<UserProfileRecord> ensureUserProfile({
    required String uid,
    required String email,
    String? username,
    int? age,
    Map<String, dynamic>? medicalInfo,
    List<String>? chronicDiseases,
    List<String>? drugAllergies,
    bool hasCompletedQuickProfileSetup = true,
  }) async {
    final normalizedEmail = _normalizedEmail(email);
    try {
      final doc = await _userDoc(uid).get();

      if (!doc.exists) {
        final legacyDoc = await _legacyUserDoc(uid).get();
        if (legacyDoc.exists) {
          final legacyProfile = await _hydrateProfile(
            uid: uid,
            data: legacyDoc.data()!,
            includeNestedCollections: false,
          );
          final migrated = _repairProfile(
            legacyProfile,
            normalizedEmail: normalizedEmail,
            username: username,
            age: age,
            chronicDiseases: chronicDiseases,
            drugAllergies: drugAllergies,
            hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
          );

          await saveProfile(migrated);
          return migrated;
        }

        final created = _buildProfile(
          uid: uid,
          email: normalizedEmail,
          username: username,
          age: age,
          medicalInfo: medicalInfo,
          chronicDiseases: chronicDiseases ?? const <String>[],
          drugAllergies: drugAllergies ?? const <String>[],
          hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
        );

        await saveProfile(created);
        return created;
      }

      final current = await _hydrateProfile(
        uid: uid,
        data: doc.data()!,
        includeNestedCollections: true,
      );

      if (!_needsRepair(
        current,
        normalizedEmail: normalizedEmail,
        username: username,
        age: age,
        chronicDiseases: chronicDiseases,
        drugAllergies: drugAllergies,
        hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
      )) {
        return current;
      }

      final repaired = _repairProfile(
        current,
        normalizedEmail: normalizedEmail,
        username: username,
        age: age,
        chronicDiseases: chronicDiseases,
        drugAllergies: drugAllergies,
        hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
      );

      await saveProfile(repaired);
      return repaired;
    } on FirebaseException catch (e) {
      throw ProfileRepositoryException(
        _firestoreError('prepare the Firestore user profile', e),
      );
    }
  }

  Future<UserProfileRecord> createUserProfile({
    required String uid,
    required String username,
    required String email,
    required List<String> chronicDiseases,
    required int age,
    Map<String, dynamic>? medicalInfo,
    List<String>? drugAllergies,
    bool hasCompletedQuickProfileSetup = true,
  }) async {
    return ensureUserProfile(
      uid: uid,
      email: email,
      username: username,
      age: age,
      medicalInfo: medicalInfo,
      chronicDiseases: chronicDiseases,
      drugAllergies: drugAllergies,
      hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile({required String uid}) async {
    final profile = await fetchProfile(uid: uid);
    return profile?.toLegacyProfileMap();
  }

  Future<UserProfileRecord> updateUserProfile({
    required String uid,
    required String username,
    required int age,
    required List<String> chronicDiseases,
    required List<String> drugAllergies,
    required Map<String, dynamic> medicalInfo,
    String? email,
    String? photoUrl,
  }) async {
    final current = await ensureUserProfile(
      uid: uid,
      email: email ?? '',
      username: username,
      age: age,
      medicalInfo: medicalInfo,
      chronicDiseases: chronicDiseases,
      drugAllergies: drugAllergies,
    );

    final profile = _buildProfile(
      uid: uid,
      email: current.email,
      username: username,
      age: age,
      medicalInfo: medicalInfo,
      chronicDiseases: chronicDiseases,
      drugAllergies: drugAllergies,
      photoUrl: photoUrl ?? current.photoUrl,
      hasCompletedQuickProfileSetup: current.hasCompletedQuickProfileSetup,
      createdAt: current.createdAt,
    );

    await saveProfile(profile);
    return profile;
  }

  Future<UserProfileRecord> saveQuickProfileSetup({
    required String uid,
    required List<String> medicalConditionNames,
    required List<String> allergyNames,
    Map<String, dynamic>? medicalInfo,
  }) async {
    final current = await fetchProfile(uid: uid);
    if (current == null) {
      throw const ProfileRepositoryException(
        'We could not load your profile to save the initial setup.',
      );
    }

    final hasIncomingMedicalInfo = medicalInfo != null;
    final normalizedBiologicalSex = hasIncomingMedicalInfo
        ? _normalizedBiologicalSex(
            medicalInfo['biologicalSex'] ?? current.biologicalSex,
          )
        : (current.biologicalSex ?? 'male');
    final isFemale = normalizedBiologicalSex == 'female';

    final updated = UserProfileRecord(
      authUid: current.authUid,
      email: current.email,
      displayName: current.displayName,
      photoUrl: current.photoUrl,
      age: current.age,
      biologicalSex: normalizedBiologicalSex,
      weightKg: hasIncomingMedicalInfo
          ? FirestoreValueParser.doubleOrNull(medicalInfo['weightKg'])
          : current.weightKg,
      heightCm: hasIncomingMedicalInfo
          ? FirestoreValueParser.doubleOrNull(medicalInfo['heightCm'])
          : current.heightCm,
      systolicPressure: hasIncomingMedicalInfo
          ? FirestoreValueParser.intOrNull(medicalInfo['systolicPressure'])
          : current.systolicPressure,
      diastolicPressure: hasIncomingMedicalInfo
          ? FirestoreValueParser.intOrNull(medicalInfo['diastolicPressure'])
          : current.diastolicPressure,
      bloodGlucose: hasIncomingMedicalInfo
          ? FirestoreValueParser.doubleOrNull(medicalInfo['bloodGlucose'])
          : current.bloodGlucose,
      isPregnant: hasIncomingMedicalInfo
          ? isFemale && medicalInfo['isPregnant'] == true
          : (normalizedBiologicalSex == 'female' ? current.isPregnant : false),
      isBreastfeeding: hasIncomingMedicalInfo
          ? isFemale && medicalInfo['isBreastfeeding'] == true
          : (normalizedBiologicalSex == 'female'
                ? current.isBreastfeeding
                : false),
      allergyNames: _normalizedStringList(allergyNames),
      medicalConditionNames: _normalizedStringList(medicalConditionNames),
      hasCompletedQuickProfileSetup: true,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );

    await saveProfile(updated);
    return updated;
  }

  Future<void> markQuickProfileSetupCompleted({required String uid}) async {
    try {
      await _userDoc(uid).set(<String, dynamic>{
        'authUid': uid,
        'hasCompletedQuickProfileSetup': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ProfileRepositoryException(
        _firestoreError('mark the initial profile setup as complete', e),
      );
    }
  }
}

final ProfileRepository profileRepository = ProfileRepository();
