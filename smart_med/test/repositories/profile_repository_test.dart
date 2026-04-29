import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';

void main() {
  group('ProfileRepository', () {
    late FakeFirebaseFirestore firestore;
    late ProfileRepository repository;

    const uid = 'user-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ProfileRepository(firestore: firestore);
    });

    test(
      'createUserProfile can leave quick profile setup incomplete for new signups',
      () async {
        final profile = await repository.createUserProfile(
          uid: uid,
          username: 'Ava',
          email: 'AVA@example.com',
          chronicDiseases: const <String>[],
          age: 34,
          hasCompletedQuickProfileSetup: false,
        );

        final snapshot = await FirestorePaths.userDoc(firestore, uid).get();

        expect(profile.hasCompletedQuickProfileSetup, isFalse);
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['hasCompletedQuickProfileSetup'], isFalse);
      },
    );

    test(
      'fetchProfile defaults quick setup to complete for legacy documents',
      () async {
        await FirestorePaths.userDoc(firestore, uid).set(<String, dynamic>{
          'authUid': uid,
          'email': 'legacy@example.com',
          'displayName': 'Legacy User',
          'drugAllergies': const <String>['Penicillin'],
        });

        final profile = await repository.fetchProfile(uid: uid);

        expect(profile, isNotNull);
        expect(profile!.hasCompletedQuickProfileSetup, isTrue);
        expect(profile.allergyNames, contains('Penicillin'));
      },
    );

    test(
      'saveQuickProfileSetup stores conditions and allergies and marks completion',
      () async {
        await repository.createUserProfile(
          uid: uid,
          username: 'Ava',
          email: 'ava@example.com',
          chronicDiseases: const <String>[],
          age: 34,
          hasCompletedQuickProfileSetup: false,
        );

        final updated = await repository.saveQuickProfileSetup(
          uid: uid,
          medicalConditionNames: const <String>[
            'Diabetes',
            'Asthma',
            'diabetes',
          ],
          allergyNames: const <String>['Ibuprofen', 'Penicillin', 'ibuprofen'],
          medicalInfo: const <String, dynamic>{
            'biologicalSex': 'female',
            'weightKg': 68.5,
            'heightCm': 170.0,
            'systolicPressure': 118,
            'diastolicPressure': 76,
            'bloodGlucose': 93.2,
            'isPregnant': true,
            'isBreastfeeding': false,
          },
        );

        final userDoc = await FirestorePaths.userDoc(firestore, uid).get();
        final allergyDocs = await FirestorePaths.allergiesCollection(
          firestore,
          uid,
        ).get();
        final conditionDocs = await FirestorePaths.medicalConditionsCollection(
          firestore,
          uid,
        ).get();

        expect(updated.hasCompletedQuickProfileSetup, isTrue);
        expect(updated.medicalConditionNames, <String>['Diabetes', 'Asthma']);
        expect(updated.allergyNames, <String>['Ibuprofen', 'Penicillin']);
        expect(updated.biologicalSex, 'female');
        expect(updated.weightKg, 68.5);
        expect(updated.heightCm, 170.0);
        expect(updated.systolicPressure, 118);
        expect(updated.diastolicPressure, 76);
        expect(updated.bloodGlucose, 93.2);
        expect(updated.isPregnant, isTrue);
        expect(updated.isBreastfeeding, isFalse);
        expect(userDoc.data()!['hasCompletedQuickProfileSetup'], isTrue);
        expect(userDoc.data()!['biologicalSex'], 'female');
        expect(userDoc.data()!['medicalInfo']['weightKg'], 68.5);
        expect(userDoc.data()!['medicalInfo']['systolicPressure'], 118);
        expect(allergyDocs.docs, hasLength(2));
        expect(conditionDocs.docs, hasLength(2));
      },
    );

    test(
      'createUserProfile can flip quick setup back to incomplete after an early bootstrap write',
      () async {
        final bootstrapped = await repository.ensureUserProfile(
          uid: uid,
          email: 'ava@example.com',
          username: 'Ava',
        );

        expect(bootstrapped.hasCompletedQuickProfileSetup, isTrue);

        final signedUp = await repository.createUserProfile(
          uid: uid,
          username: 'Ava',
          email: 'ava@example.com',
          chronicDiseases: const <String>[],
          age: 34,
          hasCompletedQuickProfileSetup: false,
        );

        final profile = await repository.fetchProfile(uid: uid);

        expect(signedUp.hasCompletedQuickProfileSetup, isFalse);
        expect(profile, isNotNull);
        expect(profile!.hasCompletedQuickProfileSetup, isFalse);
      },
    );

    test(
      'markQuickProfileSetupCompleted preserves existing safety profile data',
      () async {
        await repository.createUserProfile(
          uid: uid,
          username: 'Ava',
          email: 'ava@example.com',
          chronicDiseases: const <String>['Asthma'],
          drugAllergies: const <String>['Penicillin'],
          age: 34,
          hasCompletedQuickProfileSetup: false,
        );

        await repository.markQuickProfileSetupCompleted(uid: uid);

        final profile = await repository.fetchProfile(uid: uid);

        expect(profile, isNotNull);
        expect(profile!.hasCompletedQuickProfileSetup, isTrue);
        expect(profile.medicalConditionNames, contains('Asthma'));
        expect(profile.allergyNames, contains('Penicillin'));
      },
    );
  });
}
