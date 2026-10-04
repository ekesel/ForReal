import 'dart:async';

import 'package:dio/dio.dart';

import '../secret_store.dart';

/// HTTP access to the backend: adds the bearer token and renews it when it expires.
///
/// Refresh tokens rotate, so every refresh stores the new pair. Concurrent 401s
/// share one refresh call. If the refresh itself is rejected the user is signed out.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    HttpClientAdapter? adapter,
    this.onSignedOut,
  })  : dio = Dio(_options(baseUrl)),
        _plain = Dio(_options(baseUrl)) {
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _plain.httpClientAdapter = adapter;
    }
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      );

  /// Use for every authenticated call.
  final Dio dio;

  /// No interceptors: sign-in and token refresh.
  final Dio _plain;
  final TokenStore tokens;

  /// Called after the stored tokens were cleared because the session cannot be renewed.
  Future<void> Function()? onSignedOut;
  Future<String?>? _refreshing;

  static const _usedToken = 'forreal_used_token';
  static const _retried = 'forreal_retried';

  /// Endpoints that take no token.
  Dio get anonymous => _plain;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final current = await tokens.load();
    if (current != null) {
      options.headers['Authorization'] = 'Bearer ${current.access}';
      options.extra[_usedToken] = current.access;
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    if (error.response?.statusCode != 401 || request.extra[_retried] == true) {
      return handler.next(error);
    }
    final String? access;
    try {
      access = await _refresh(request.extra[_usedToken] as String?);
    } on DioException catch (refreshError) {
      // The refresh could not be attempted (offline, server down): not a sign-out.
      return handler.next(refreshError);
    }
    if (access == null) return handler.next(error);
    try {
      request.extra[_retried] = true;
      request.headers['Authorization'] = 'Bearer $access';
      handler.resolve(await _plain.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// One refresh at a time; callers that arrive meanwhile wait for the same result.
  Future<String?> _refresh(String? usedAccess) {
    return _refreshing ??= _doRefresh(usedAccess).whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh(String? usedAccess) async {
    final current = await tokens.load();
    if (current == null) {
      await _signOut();
      return null;
    }
    // Another isolate (background sync, a notification action) already renewed it.
    if (usedAccess != null && current.access != usedAccess) return current.access;
    try {
      final response = await _plain.post<dynamic>('auth/token/refresh/', data: {'refresh': current.refresh});
      final data = response.data as Map;
      final next = AuthTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String? ?? current.refresh,
      );
      await tokens.save(next);
      return next.access;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        await _signOut();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _signOut() async {
    await tokens.clear();
    await onSignedOut?.call();
  }
}
