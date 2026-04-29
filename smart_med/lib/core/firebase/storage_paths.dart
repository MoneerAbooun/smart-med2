class StoragePaths {
  const StoragePaths._();

  static String profileImage({required String uid, required String extension}) {
    final version = DateTime.now().millisecondsSinceEpoch;
    return 'users/$uid/profile/profile_$version.$extension';
  }

  static String medicationImage({
    required String uid,
    required String medicationId,
    required String extension,
  }) {
    final version = DateTime.now().millisecondsSinceEpoch;
    return 'users/$uid/medications/$medicationId/medicine_$version.$extension';
  }
}
