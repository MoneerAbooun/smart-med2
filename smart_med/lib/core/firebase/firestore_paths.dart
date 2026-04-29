import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaths {
  const FirestorePaths._();

  static const String users = 'users';
  static const String legacyUsers = 'Users';
  static const String medications = 'medications';
  static const String reminders = 'reminders';
  static const String allergies = 'allergies';
  static const String medicalConditions = 'medical_conditions';
  static const String interactionHistory = 'interaction_history';
  static const String drugCatalog = 'drug_catalog';
  static const String drugInteractions = 'drug_interactions';
  static const String alternatives = 'alternatives';

  static CollectionReference<Map<String, dynamic>> usersCollection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection(users);
  }

  static DocumentReference<Map<String, dynamic>> userDoc(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return usersCollection(firestore).doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> legacyUsersCollection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection(legacyUsers);
  }

  static DocumentReference<Map<String, dynamic>> legacyUserDoc(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return legacyUsersCollection(firestore).doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> medicationsCollection(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return userDoc(firestore, uid).collection(medications);
  }

  static DocumentReference<Map<String, dynamic>> medicationDoc(
    FirebaseFirestore firestore,
    String uid,
    String medicationId,
  ) {
    return medicationsCollection(firestore, uid).doc(medicationId);
  }

  static CollectionReference<Map<String, dynamic>> remindersCollection(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return userDoc(firestore, uid).collection(reminders);
  }

  static DocumentReference<Map<String, dynamic>> reminderDoc(
    FirebaseFirestore firestore,
    String uid,
    String reminderId,
  ) {
    return remindersCollection(firestore, uid).doc(reminderId);
  }

  static CollectionReference<Map<String, dynamic>> allergiesCollection(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return userDoc(firestore, uid).collection(allergies);
  }

  static DocumentReference<Map<String, dynamic>> allergyDoc(
    FirebaseFirestore firestore,
    String uid,
    String allergyId,
  ) {
    return allergiesCollection(firestore, uid).doc(allergyId);
  }

  static CollectionReference<Map<String, dynamic>> medicalConditionsCollection(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return userDoc(firestore, uid).collection(medicalConditions);
  }

  static DocumentReference<Map<String, dynamic>> medicalConditionDoc(
    FirebaseFirestore firestore,
    String uid,
    String conditionId,
  ) {
    return medicalConditionsCollection(firestore, uid).doc(conditionId);
  }

  static CollectionReference<Map<String, dynamic>> interactionHistoryCollection(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return userDoc(firestore, uid).collection(interactionHistory);
  }

  static DocumentReference<Map<String, dynamic>> interactionHistoryDoc(
    FirebaseFirestore firestore,
    String uid,
    String historyId,
  ) {
    return interactionHistoryCollection(firestore, uid).doc(historyId);
  }

  static CollectionReference<Map<String, dynamic>> drugCatalogCollection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection(drugCatalog);
  }

  static DocumentReference<Map<String, dynamic>> drugCatalogDoc(
    FirebaseFirestore firestore,
    String drugId,
  ) {
    return drugCatalogCollection(firestore).doc(drugId);
  }

  static CollectionReference<Map<String, dynamic>> drugInteractionsCollection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection(drugInteractions);
  }

  static DocumentReference<Map<String, dynamic>> drugInteractionDoc(
    FirebaseFirestore firestore,
    String pairKey,
  ) {
    return drugInteractionsCollection(firestore).doc(pairKey);
  }

  static CollectionReference<Map<String, dynamic>> alternativesCollection(
    FirebaseFirestore firestore,
    String drugId,
  ) {
    return drugCatalogDoc(firestore, drugId).collection(alternatives);
  }

  static DocumentReference<Map<String, dynamic>> alternativeDoc(
    FirebaseFirestore firestore,
    String drugId,
    String alternativeId,
  ) {
    return alternativesCollection(firestore, drugId).doc(alternativeId);
  }
}
