import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';

class UserProfileRecord {
  UserProfileRecord({
    required this.authUid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.age,
    this.biologicalSex,
    this.weightKg,
    this.heightCm,
    this.systolicPressure,
    this.diastolicPressure,
    this.bloodGlucose,
    required this.isPregnant,
    required this.isBreastfeeding,
    this.allergyNames = const <String>[],
    this.medicalConditionNames = const <String>[],
    this.hasCompletedQuickProfileSetup = true,
    this.createdAt,
    this.updatedAt,
  });

  final String authUid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int? age;
  final String? biologicalSex;
  final double? weightKg;
  final double? heightCm;
  final int? systolicPressure;
  final int? diastolicPressure;
  final double? bloodGlucose;
  final bool isPregnant;
  final bool isBreastfeeding;
  final List<String> allergyNames;
  final List<String> medicalConditionNames;
  final bool hasCompletedQuickProfileSetup;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfileRecord.fromMap(String authUid, Map<String, dynamic> map) {
    final medicalInfo = FirestoreValueParser.map(map['medicalInfo']);
    final hasCompletedQuickProfileSetup =
        map.containsKey('hasCompletedQuickProfileSetup')
        ? FirestoreValueParser.boolOrDefault(
            map['hasCompletedQuickProfileSetup'],
          )
        : true;

    return UserProfileRecord(
      authUid: authUid,
      email: FirestoreValueParser.stringOrNull(map['email']) ?? '',
      displayName:
          FirestoreValueParser.stringOrNull(map['displayName']) ??
          FirestoreValueParser.stringOrNull(map['username']) ??
          '',
      photoUrl: FirestoreValueParser.stringOrNull(map['photoUrl']),
      age: FirestoreValueParser.intOrNull(map['age']),
      biologicalSex:
          FirestoreValueParser.stringOrNull(map['biologicalSex']) ??
          FirestoreValueParser.stringOrNull(medicalInfo['biologicalSex']),
      weightKg:
          FirestoreValueParser.doubleOrNull(map['weightKg']) ??
          FirestoreValueParser.doubleOrNull(medicalInfo['weightKg']),
      heightCm:
          FirestoreValueParser.doubleOrNull(map['heightCm']) ??
          FirestoreValueParser.doubleOrNull(medicalInfo['heightCm']),
      systolicPressure:
          FirestoreValueParser.intOrNull(map['systolicPressure']) ??
          FirestoreValueParser.intOrNull(medicalInfo['systolicPressure']),
      diastolicPressure:
          FirestoreValueParser.intOrNull(map['diastolicPressure']) ??
          FirestoreValueParser.intOrNull(medicalInfo['diastolicPressure']),
      bloodGlucose:
          FirestoreValueParser.doubleOrNull(map['bloodGlucose']) ??
          FirestoreValueParser.doubleOrNull(medicalInfo['bloodGlucose']),
      isPregnant: FirestoreValueParser.boolOrDefault(
        map['isPregnant'] ?? medicalInfo['isPregnant'],
      ),
      isBreastfeeding: FirestoreValueParser.boolOrDefault(
        map['isBreastfeeding'] ?? medicalInfo['isBreastfeeding'],
      ),
      allergyNames:
          FirestoreValueParser.stringList(map['allergyNames']).isNotEmpty
          ? FirestoreValueParser.stringList(map['allergyNames'])
          : FirestoreValueParser.stringList(map['drugAllergies']),
      medicalConditionNames:
          FirestoreValueParser.stringList(
            map['medicalConditionNames'],
          ).isNotEmpty
          ? FirestoreValueParser.stringList(map['medicalConditionNames'])
          : FirestoreValueParser.stringList(map['chronicDiseases']),
      hasCompletedQuickProfileSetup: hasCompletedQuickProfileSetup,
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'authUid': authUid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'age': age,
      'biologicalSex': biologicalSex,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'systolicPressure': systolicPressure,
      'diastolicPressure': diastolicPressure,
      'bloodGlucose': bloodGlucose,
      'isPregnant': isPregnant,
      'isBreastfeeding': isBreastfeeding,
      'allergyNames': allergyNames,
      'medicalConditionNames': medicalConditionNames,
      'hasCompletedQuickProfileSetup': hasCompletedQuickProfileSetup,
      'createdAt': createdAt,
      'updatedAt': updatedAt,

      // Compatibility fields while the profile UI is still being migrated.
      'username': displayName,
      'drugAllergies': allergyNames,
      'chronicDiseases': medicalConditionNames,
      'medicalInfo': {
        'biologicalSex': biologicalSex ?? 'male',
        'weightKg': weightKg,
        'heightCm': heightCm,
        'systolicPressure': systolicPressure,
        'diastolicPressure': diastolicPressure,
        'bloodGlucose': bloodGlucose,
        'isPregnant': isPregnant,
        'isBreastfeeding': isBreastfeeding,
      },
    });
  }

  Map<String, dynamic> toLegacyProfileMap() {
    return {
      'username': displayName,
      'email': email,
      'age': age,
      'chronicDiseases': medicalConditionNames,
      'drugAllergies': allergyNames,
      'medicalInfo': {
        'biologicalSex': biologicalSex ?? 'male',
        'weightKg': weightKg,
        'heightCm': heightCm,
        'systolicPressure': systolicPressure,
        'diastolicPressure': diastolicPressure,
        'bloodGlucose': bloodGlucose,
        'isPregnant': isPregnant,
        'isBreastfeeding': isBreastfeeding,
      },
    };
  }
}
