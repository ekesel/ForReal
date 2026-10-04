import 'package:dio/dio.dart';

/// Any failed API call, in the terms the app acts on.
class ApiException implements Exception {
  const ApiException({
    this.statusCode,
    this.code,
    required this.message,
    this.fieldErrors = const {},
    this.body,
  });

  /// Null when the server was not reached.
  final int? statusCode;

  /// The backend's machine-readable `code`, when it sends one
  /// (too_many_requests, expired, invalid, too_many_attempts, inactive, dependency, not_taggable,
  /// consent_required, location_consent_required, no_active_account, token_not_valid).
  final String? code;

  /// Something that can be shown to the user.
  final String message;

  /// DRF validation errors by field name.
  final Map<String, String> fieldErrors;

  /// The decoded response body, for callers that need more than the summary.
  final Object? body;

  bool get isNetwork => statusCode == null;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isRateLimited => statusCode == 429;

  /// Worth trying again later without changing the request.
  bool get isRetryable => isNetwork || isServerError || isRateLimited;

  /// The server refuses payment data because the private-analytics consent is
  /// missing. Only this code means that; any other 403 is an ordinary error.
  bool get isConsentRequired => statusCode == 403 && code == 'consent_required';

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return ApiException(message: 'Something went wrong. Please try again.', body: error.toString());
    }
    final response = error.response;
    if (response == null) {
      return const ApiException(message: 'No connection to the server. Check your internet and try again.');
    }
    final data = response.data;
    String? code;
    String? detail;
    final fields = <String, String>{};
    if (data is Map) {
      if (data['code'] is String) code = data['code'] as String;
      if (data['detail'] is String) detail = data['detail'] as String;
      data.forEach((key, value) {
        if (key == 'code' || key == 'detail') return;
        final text = _firstText(value);
        if (text != null) fields['$key'] = text;
      });
    }
    final status = response.statusCode;
    final message = detail ??
        (fields.isNotEmpty ? fields.values.first : null) ??
        (status != null && status >= 500
            ? 'The server had a problem. Please try again in a moment.'
            : 'The request was not accepted ($status).');
    return ApiException(statusCode: status, code: code, message: message, fieldErrors: fields, body: data);
  }

  static String? _firstText(Object? value) {
    if (value is String) return value;
    if (value is List) {
      for (final v in value) {
        final text = _firstText(v);
        if (text != null) return text;
      }
    }
    if (value is Map) {
      for (final v in value.values) {
        final text = _firstText(v);
        if (text != null) return text;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// Runs an API call and turns any failure into an [ApiException].
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw ApiException.from(e);
  }
}
