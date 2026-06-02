import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';

class PersonalizedExplanationRepositoryException implements Exception {
  const PersonalizedExplanationRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PersonalizedExplanationRepository {
  static const String _signInAgainMessage =
      'Your session expired. Please sign in again to use Smart Med AI features.';

  PersonalizedExplanationRepository({
    FirebaseAuth? firebaseAuth,
    ApiClient? apiClient,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _apiClient = apiClient ?? ApiClient();

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;

  Future<PersonalizedExplanationResponse> generateExplanation({
    List<String> medicationIds = const <String>[],
    bool includeInactive = false,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'detail',
        'medication_ids': medicationIds,
        'include_inactive': includeInactive,
        'simple_language': simpleLanguage,
      },
    );
  }

  Future<PersonalizedExplanationResponse> generateSafetyBrief({
    bool includeInactive = false,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'brief',
        'include_inactive': includeInactive,
        'simple_language': simpleLanguage,
      },
    );
  }

  Future<PersonalizedExplanationResponse> generateSafetyPreview({
    required DraftMedicationInput draftMedication,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'preview',
        'simple_language': simpleLanguage,
        'draft_medication': draftMedication.toMap(),
      },
    );
  }

  Future<PersonalizedExplanationResponse> _sendRequest({
    required Map<String, dynamic> body,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PersonalizedExplanationRepositoryException(
        'Please sign in again to generate an explanation.',
      );
    }

    try {
      return await _sendAuthorizedRequest(user: user, body: body);
    } on PersonalizedExplanationRepositoryException {
      rethrow;
    } on ApiClientException catch (error) {
      throw PersonalizedExplanationRepositoryException(
        _friendlyApiErrorMessage(error),
      );
    } on FirebaseAuthException {
      throw const PersonalizedExplanationRepositoryException(
        _signInAgainMessage,
      );
    } catch (error) {
      throw PersonalizedExplanationRepositoryException(error.toString());
    }
  }

  Future<PersonalizedExplanationResponse> _sendAuthorizedRequest({
    required User user,
    required Map<String, dynamic> body,
  }) async {
    final initialToken = await _getRequiredIdToken(user);

    try {
      final response = await _postPersonalizedExplanation(
        body: body,
        idToken: initialToken,
      );
      return PersonalizedExplanationResponse.fromMap(response);
    } on ApiClientException catch (error) {
      if (!_shouldRetryWithFreshToken(error)) {
        rethrow;
      }

      final refreshedToken = await _getRequiredIdToken(
        user,
        forceRefresh: true,
      );
      final response = await _postPersonalizedExplanation(
        body: body,
        idToken: refreshedToken,
      );
      return PersonalizedExplanationResponse.fromMap(response);
    }
  }

  Future<String> _getRequiredIdToken(
    User user, {
    bool forceRefresh = false,
  }) async {
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw const PersonalizedExplanationRepositoryException(
        _signInAgainMessage,
      );
    }
    return idToken;
  }

  Future<Map<String, dynamic>> _postPersonalizedExplanation({
    required Map<String, dynamic> body,
    required String idToken,
  }) {
    return _apiClient.postJson(
      path: '/personalized-explanation',
      headers: <String, String>{'Authorization': 'Bearer $idToken'},
      body: body,
    );
  }

  bool _shouldRetryWithFreshToken(ApiClientException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 401 ||
        message.contains('invalid firebase token') ||
        message.contains('missing firebase bearer token');
  }

  String _friendlyApiErrorMessage(ApiClientException error) {
    if (_shouldRetryWithFreshToken(error)) {
      return _signInAgainMessage;
    }

    return error.message;
  }
}

final PersonalizedExplanationRepository personalizedExplanationRepository =
    PersonalizedExplanationRepository();
