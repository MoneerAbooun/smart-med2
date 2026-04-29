import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:smart_med/core/config/app_config.dart';

class ApiClientException implements Exception {
  const ApiClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _buildUri(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final resolvedUri = baseUri.resolve(normalizedPath);
    if (queryParameters.isEmpty) {
      return resolvedUri;
    }

    return resolvedUri.replace(
      queryParameters: <String, String>{
        ...resolvedUri.queryParameters,
        ...queryParameters,
      },
    );
  }

  Future<Map<String, dynamic>> getJson({
    required String path,
    Map<String, String> queryParameters = const <String, String>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    return _sendJsonRequest(() {
      return _httpClient.get(
        _buildUri(path, queryParameters: queryParameters),
        headers: headers,
      );
    });
  }

  Future<Map<String, dynamic>> postJson({
    required String path,
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) {
    return _sendJsonRequest(() {
      return _httpClient.post(
        _buildUri(path),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(body),
      );
    });
  }

  Future<Map<String, dynamic>> postMultipart({
    required String path,
    required Uint8List fileBytes,
    required String fileField,
    required String fileName,
    Map<String, String> fields = const <String, String>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    return _sendJsonRequest(() async {
      final request = http.MultipartRequest('POST', _buildUri(path));
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });
  }

  Future<Map<String, dynamic>> _sendJsonRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw const ApiClientException(
            'Backend timeout. Check if FastAPI is running and the phone can reach the backend URL.',
          );
        },
      );

      final parsedBody = _parseJsonMap(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail =
            parsedBody?['detail']?.toString() ??
            'Request failed with status ${response.statusCode}.';
        throw ApiClientException(detail, statusCode: response.statusCode);
      }

      if (parsedBody == null) {
        throw const ApiClientException('The API returned an empty response.');
      }

      return parsedBody;
    } on http.ClientException {
      throw const ApiClientException(
        'Unable to reach the backend. Check if FastAPI is running and the phone can reach the backend URL.',
      );
    }
  }

  Map<String, dynamic>? _parseJsonMap(http.Response response) {
    Map<String, dynamic>? parsedBody;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          parsedBody = decoded;
        } else if (decoded is Map) {
          parsedBody = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        parsedBody = null;
      }
    }
    return parsedBody;
  }
}
