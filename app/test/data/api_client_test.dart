import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/secret_store.dart';

import '../support/fake_api.dart';

const me = {'id': 'u-1', 'phone': '+919876543210', 'display_name': '', 'created_at': '2026-08-01T00:00:00Z'};

void main() {
  late TestBackend backend;
  late AccountApi account;

  /// me/ accepts only [valid]; anything else is 401, like an expired access token.
  void meRequires(String valid) {
    backend.api.on('GET', 'me/', (r) {
      return r.bearer == valid
          ? const FakeResponse.ok(me)
          : const FakeResponse(401, {'detail': 'Token is invalid or expired', 'code': 'token_not_valid'});
    });
  }

  setUp(() {
    backend = TestBackend();
    account = AccountApi(backend.client);
  });

  test('requests carry the bearer token', () async {
    meRequires('access-1');
    final user = await account.me();
    expect(user.phone, '+919876543210');
    expect(backend.api.requests.single.bearer, 'access-1');
  });

  test('a 401 refreshes, stores the rotated pair and retries', () async {
    meRequires('access-2');
    backend.api.reply('POST', 'auth/token/refresh/', {'access': 'access-2', 'refresh': 'refresh-2'});

    final user = await account.me();

    expect(user.id, 'u-1');
    final refresh = backend.api.to('POST', 'auth/token/refresh/').single;
    expect(refresh.json, {'refresh': 'refresh-1'});
    expect(refresh.bearer, isNull, reason: 'the refresh call itself is anonymous');
    expect([for (final r in backend.api.to('GET', 'me/')) r.bearer], ['access-1', 'access-2']);
    final stored = await backend.tokens.load();
    expect(stored!.access, 'access-2');
    expect(stored.refresh, 'refresh-2', reason: 'refresh tokens rotate; the new one must be kept');
    expect(backend.signOuts, 0);
  });

  test('concurrent 401s share one refresh', () async {
    meRequires('access-2');
    backend.api.on('POST', 'auth/token/refresh/', (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const FakeResponse.ok({'access': 'access-2', 'refresh': 'refresh-2'});
    });

    final users = await Future.wait([account.me(), account.me(), account.me()]);

    expect(users, hasLength(3));
    expect(backend.api.to('POST', 'auth/token/refresh/'), hasLength(1));
  });

  test('a rejected refresh signs the user out', () async {
    meRequires('never');
    backend.api.reply('POST', 'auth/token/refresh/', {'detail': 'Token is invalid or expired', 'code': 'token_not_valid'},
        status: 401);

    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    expect(await backend.tokens.load(), isNull);
    expect(backend.signOuts, 1);
  });

  test('refresh for a deleted or disabled account (401 no_active_account) signs out', () async {
    meRequires('never');
    backend.api.reply('POST', 'auth/token/refresh/',
        {'detail': 'No active account found for the given token.', 'code': 'no_active_account'},
        status: 401);

    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    expect(await backend.tokens.load(), isNull);
    expect(backend.signOuts, 1);
    expect(backend.api.to('POST', 'auth/token/refresh/'), hasLength(1));
  });

  test('a refresh that cannot reach the server keeps the session', () async {
    meRequires('never');
    backend.api.on('POST', 'auth/token/refresh/', (_) => throw const Offline());

    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', isTrue)));

    expect((await backend.tokens.load())!.refresh, 'refresh-1');
    expect(backend.signOuts, 0);
  });

  test('a server error during refresh keeps the session', () async {
    meRequires('never');
    backend.api.reply('POST', 'auth/token/refresh/', {'detail': 'boom'}, status: 503);

    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.isServerError, 'server', isTrue)));

    expect(await backend.tokens.load(), isNotNull);
    expect(backend.signOuts, 0);
  });

  test('tokens renewed by another isolate are used without a second refresh', () async {
    var calls = 0;
    backend.api.on('GET', 'me/', (r) async {
      calls++;
      if (calls == 1) {
        // While this request was in flight, a background isolate rotated the tokens.
        await backend.tokens.save(const AuthTokens(access: 'access-9', refresh: 'refresh-9'));
        return const FakeResponse(401, {'code': 'token_not_valid'});
      }
      return r.bearer == 'access-9' ? const FakeResponse.ok(me) : const FakeResponse(401);
    });

    await account.me();

    expect(backend.api.to('POST', 'auth/token/refresh/'), isEmpty);
    expect(backend.api.to('GET', 'me/').last.bearer, 'access-9');
  });

  test('a 401 after the retry is not retried again', () async {
    meRequires('never');
    backend.api.reply('POST', 'auth/token/refresh/', {'access': 'access-2', 'refresh': 'refresh-2'});

    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    expect(backend.api.to('GET', 'me/'), hasLength(2));
    expect(backend.api.to('POST', 'auth/token/refresh/'), hasLength(1));
  });

  test('without tokens a 401 signs out and does not call refresh', () async {
    backend = TestBackend(signedIn: false);
    account = AccountApi(backend.client);
    meRequires('never');

    await expectLater(account.me(), throwsA(isA<ApiException>()));

    expect(backend.api.to('POST', 'auth/token/refresh/'), isEmpty);
    expect(backend.signOuts, 1);
  });
}
