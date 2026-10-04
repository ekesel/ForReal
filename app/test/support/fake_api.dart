import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:forreal/data/api/api_client.dart';
import 'package:forreal/data/secret_store.dart';

const testBaseUrl = 'http://api.test/api/v1/';

class RecordedRequest {
  RecordedRequest(this.method, this.path, this.query, this.data, this.headers);
  final String method;

  /// Path below /api/v1/, e.g. 'transactions/batch/'.
  final String path;
  final Map<String, String> query;
  final Object? data;
  final Map<String, dynamic> headers;

  String? get bearer {
    final value = headers['Authorization'] as String?;
    return value?.replaceFirst('Bearer ', '');
  }

  Map<String, dynamic> get json => Map<String, dynamic>.from(data! as Map);

  @override
  String toString() => '$method $path';
}

class FakeResponse {
  const FakeResponse(this.status, [this.body]);
  const FakeResponse.ok([this.body]) : status = 200;
  final int status;
  final Object? body;
}

/// Thrown from a handler to simulate "the server was not reached".
class Offline implements Exception {
  const Offline();
}

typedef FakeHandler = FutureOr<FakeResponse> Function(RecordedRequest request);

/// A dio adapter that answers from registered handlers and records every request.
class FakeApi implements HttpClientAdapter {
  final List<RecordedRequest> requests = [];
  final Map<String, FakeHandler> _handlers = {};

  void on(String method, String path, FakeHandler handler) => _handlers['$method $path'] = handler;

  void reply(String method, String path, Object? body, {int status = 200}) =>
      on(method, path, (_) => FakeResponse(status, body));

  List<RecordedRequest> to(String method, String path) =>
      [for (final r in requests) if (r.method == method && r.path == path) r];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final uri = options.uri;
    final path = uri.path.replaceFirst('/api/v1/', '');
    final request = RecordedRequest(options.method, path, uri.queryParameters, options.data, Map.of(options.headers));
    requests.add(request);
    final handler = _handlers['${options.method} $path'];
    if (handler == null) {
      return _body(const FakeResponse(404, {'detail': 'Not found.'}));
    }
    try {
      return _body(await handler(request));
    } on Offline {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
  }

  ResponseBody _body(FakeResponse response) => ResponseBody.fromString(
        response.body == null ? '' : jsonEncode(response.body),
        response.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class TestBackend {
  TestBackend({bool signedIn = true}) {
    if (signedIn) {
      secrets.values['jwt_access'] = 'access-1';
      secrets.values['jwt_refresh'] = 'refresh-1';
    }
    client = ApiClient(
      baseUrl: testBaseUrl,
      tokens: tokens,
      adapter: api,
      onSignedOut: () async => signOuts++,
    );
  }

  final api = FakeApi();
  final secrets = MemorySecretStore();
  late final tokens = TokenStore(secrets);
  late final ApiClient client;
  int signOuts = 0;
}
