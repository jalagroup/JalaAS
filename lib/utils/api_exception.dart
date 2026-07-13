// lib/utils/api_exception.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when an API call returns a non-200 status code.
/// Carries the user-visible message extracted from the response body's
/// "message" field (falls back to a generic Arabic string if absent).
class ApiException implements Exception {
  final String userMessage;
  final int? statusCode;

  const ApiException(this.userMessage, {this.statusCode});

  /// Parse the HTTP response and build an [ApiException] with the real message.
  factory ApiException.fromResponse(http.Response response) {
    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ??
          'خطأ في الخادم (${response.statusCode})';
    } catch (_) {
      message = 'خطأ في الخادم (${response.statusCode})';
    }
    return ApiException(message, statusCode: response.statusCode);
  }

  @override
  String toString() => userMessage;
}
