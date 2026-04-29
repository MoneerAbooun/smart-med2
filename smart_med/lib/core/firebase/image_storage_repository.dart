import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/network/api_client.dart';

class ImageStorageRepositoryException implements Exception {
  const ImageStorageRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageStorageRepository {
  static const String _signInAgainMessage =
      'Your session expired. Please sign in again to upload images.';

  ImageStorageRepository({FirebaseAuth? firebaseAuth, ApiClient? apiClient})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? ApiClient();

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;

  Future<String> uploadProfileImage({
    required String uid,
    required XFile image,
  }) async {
    final user = _requireSignedInUser(expectedUid: uid);
    final fileBytes = await image.readAsBytes();

    return _uploadAuthorizedImage(
      user: user,
      image: image,
      fileBytes: fileBytes,
      path: '/api/uploads/profile-image',
      failureAction: 'upload the profile image',
    );
  }

  Future<String> uploadMedicationImage({required XFile image}) async {
    final user = _requireSignedInUser();
    final fileBytes = await image.readAsBytes();

    return _uploadAuthorizedImage(
      user: user,
      image: image,
      fileBytes: fileBytes,
      path: '/api/uploads/medication-image',
      failureAction: 'upload the medication image',
    );
  }

  Future<String> _uploadAuthorizedImage({
    required User user,
    required XFile image,
    required Uint8List fileBytes,
    required String path,
    required String failureAction,
  }) async {
    try {
      final initialToken = await _getRequiredIdToken(user);

      try {
        return await _postImage(
          path: path,
          image: image,
          fileBytes: fileBytes,
          idToken: initialToken,
        );
      } on ApiClientException catch (error) {
        if (!_shouldRetryWithFreshToken(error)) {
          rethrow;
        }

        final refreshedToken = await _getRequiredIdToken(
          user,
          forceRefresh: true,
        );
        return await _postImage(
          path: path,
          image: image,
          fileBytes: fileBytes,
          idToken: refreshedToken,
        );
      }
    } on ImageStorageRepositoryException {
      rethrow;
    } on ApiClientException catch (error) {
      throw ImageStorageRepositoryException(
        _friendlyApiErrorMessage(error, failureAction: failureAction),
      );
    } on FirebaseAuthException {
      throw const ImageStorageRepositoryException(_signInAgainMessage);
    } catch (error) {
      throw ImageStorageRepositoryException(
        'Failed to $failureAction. ${error.toString()}',
      );
    }
  }

  Future<String> _postImage({
    required String path,
    required XFile image,
    required Uint8List fileBytes,
    required String idToken,
  }) async {
    final response = await _apiClient.postMultipart(
      path: path,
      fileBytes: fileBytes,
      fileField: 'image',
      fileName: _normalizedFileName(image.name, image.path),
      headers: <String, String>{'Authorization': 'Bearer $idToken'},
    );

    final imageUrl =
        response['image_url']?.toString().trim() ??
        response['imageUrl']?.toString().trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const ImageStorageRepositoryException(
        'The image upload response did not include an image URL.',
      );
    }

    return imageUrl;
  }

  Future<String> _getRequiredIdToken(
    User user, {
    bool forceRefresh = false,
  }) async {
    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw const ImageStorageRepositoryException(_signInAgainMessage);
    }
    return idToken;
  }

  User _requireSignedInUser({String? expectedUid}) {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const ImageStorageRepositoryException(
        'User must be logged in to upload images.',
      );
    }

    if (expectedUid != null && user.uid != expectedUid) {
      throw const ImageStorageRepositoryException(
        'Signed-in user does not match the upload destination.',
      );
    }

    return user;
  }

  bool _shouldRetryWithFreshToken(ApiClientException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 401 ||
        message.contains('invalid firebase token') ||
        message.contains('missing firebase bearer token');
  }

  String _friendlyApiErrorMessage(
    ApiClientException error, {
    required String failureAction,
  }) {
    if (_shouldRetryWithFreshToken(error)) {
      return _signInAgainMessage;
    }

    if (error.statusCode == 413) {
      return 'Image is too large. Please choose a smaller file.';
    }

    if (error.statusCode == 415) {
      return 'Unsupported image type. Please choose a JPG, PNG, WEBP, or HEIC image.';
    }

    return 'Failed to $failureAction. ${error.message}';
  }

  String _normalizedFileName(String fileName, String path) {
    final extension = _normalizedExtension(fileName, path);
    return '${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  String _normalizedExtension(String fileName, String path) {
    final candidates = [fileName, path];

    for (final candidate in candidates) {
      final normalized = candidate.trim().toLowerCase();
      final lastDot = normalized.lastIndexOf('.');

      if (lastDot == -1 || lastDot == normalized.length - 1) {
        continue;
      }

      final extension = normalized.substring(lastDot + 1);
      if (_supportedExtensions.contains(extension)) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }

    return 'jpg';
  }

  static const Set<String> _supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  };
}

final ImageStorageRepository imageStorageRepository = ImageStorageRepository();
