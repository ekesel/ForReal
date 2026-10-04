import '../models.dart';
import '../secret_store.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// One method per backend endpoint the app uses. Every failure surfaces as an
/// [ApiException].

class AuthApi {
  AuthApi(this._client, this._tokens);
  final ApiClient _client;
  final TokenStore _tokens;

  Future<OtpRequestResult> requestOtp(String phone) => guard(() async {
        final res = await _client.anonymous.post<dynamic>('auth/otp/request/', data: {'phone': phone});
        return OtpRequestResult.fromJson(asMap(res.data));
      });

  /// Verifies the code and stores the tokens.
  Future<AuthSession> verifyOtp(String phone, String code) => guard(() async {
        final res = await _client.anonymous.post<dynamic>('auth/otp/verify/', data: {'phone': phone, 'code': code});
        final session = AuthSession.fromJson(asMap(res.data));
        await _tokens.save(AuthTokens(access: session.access, refresh: session.refresh));
        return session;
      });
}

class AccountApi {
  AccountApi(this._client);
  final ApiClient _client;

  Future<User> me() => guard(() async {
        final res = await _client.dio.get<dynamic>('me/');
        return User.fromJson(asMap(res.data));
      });

  Future<User> setDisplayName(String name) => guard(() async {
        final res = await _client.dio.patch<dynamic>('me/', data: {'display_name': name});
        return User.fromJson(asMap(res.data));
      });

  Future<void> deleteAccount() => guard(() async {
        await _client.dio.delete<dynamic>('me/');
      });

  /// Everything the server holds about the user, as decoded JSON.
  Future<Map<String, dynamic>> export() => guard(() async {
        final res = await _client.dio.get<dynamic>('me/export/');
        return asMap(res.data);
      });

  Future<void> registerDevice({required String deviceId, required String appVersion, String pushToken = ''}) =>
      guard(() async {
        await _client.dio.put<dynamic>('me/device/', data: {
          'device_id': deviceId,
          'platform': 'android',
          'app_version': appVersion,
          'push_token': pushToken,
        });
      });
}

class ConsentApi {
  ConsentApi(this._client);
  final ApiClient _client;

  Future<ConsentState> current() => guard(() async {
        final res = await _client.dio.get<dynamic>('consents/');
        return ConsentState.fromJson(asMap(asMap(res.data)['consents']));
      });

  /// Grants or withdraws one purpose. The server applies the dependency rules and
  /// answers with the full new state; a missing parent is a 400 with code "dependency".
  Future<ConsentState> set(Purpose purpose, {required bool granted, required String noticeVersion}) =>
      guard(() async {
        final res = await _client.dio.post<dynamic>('consents/', data: {
          'purpose': purpose.wire,
          'granted': granted,
          'notice_version': noticeVersion,
        });
        return ConsentState.fromJson(asMap(asMap(res.data)['consents']));
      });
}

class TemplatesApi {
  TemplatesApi(this._client);
  final ApiClient _client;

  Future<TemplatesResponse> fetch({int? knownVersion}) => guard(() async {
        final res = await _client.dio.get<dynamic>(
          'parser-templates/',
          queryParameters: {if (knownVersion != null) 'version': '$knownVersion'},
        );
        final data = asMap(res.data);
        return TemplatesResponse(
          version: (data['version'] as num).toInt(),
          changed: data['changed'] as bool? ?? true,
          templates: [for (final t in data['templates'] as List? ?? const []) asMap(t)],
        );
      });
}

class TransactionsApi {
  TransactionsApi(this._client);
  final ApiClient _client;

  /// Uploads up to 200 payments. Results come back in the order sent.
  Future<List<IngestResult>> ingest(List<IngestRow> rows) => guard(() async {
        final res = await _client.dio.post<dynamic>(
          'transactions/batch/',
          data: {'transactions': [for (final r in rows) r.toJson()]},
        );
        return [for (final r in asMap(res.data)['results'] as List) IngestResult.fromJson(asMap(r))];
      });

  /// One page of the user's payments, newest first. Pass [next] from the previous page.
  Future<TransactionPage> list({String? next}) => guard(() async {
        final res = await _client.dio.get<dynamic>(next ?? 'transactions/');
        final data = asMap(res.data);
        return TransactionPage(
          results: [for (final t in data['results'] as List) ServerTransaction.fromJson(asMap(t))],
          next: data['next'] as String?,
        );
      });

  Future<ServerTransaction> get(String id) => guard(() async {
        final res = await _client.dio.get<dynamic>('transactions/$id/');
        return ServerTransaction.fromJson(asMap(res.data));
      });

  /// Attaches a location to a payment ingested without one. The first location wins.
  Future<ServerTransaction> setLocation(String id, LatLng location) => guard(() async {
        final res = await _client.dio.post<dynamic>('transactions/$id/location/', data: location.coarse.toJson());
        return ServerTransaction.fromJson(asMap(res.data));
      });
}

class MerchantsApi {
  MerchantsApi(this._client);
  final ApiClient _client;

  Future<List<Category>> categories() => guard(() async {
        final res = await _client.dio.get<dynamic>('categories/');
        return [for (final c in asMap(res.data)['categories'] as List) Category.fromJson(asMap(c))];
      });

  /// Shops other users confirmed for this payee, near [near] when given.
  Future<List<Merchant>> suggestions(int payeeId, {LatLng? near}) => guard(() async {
        final res = await _client.dio.get<dynamic>(
          'payees/$payeeId/suggestions/',
          queryParameters: near?.coarse.toJson(),
        );
        return [for (final m in asMap(res.data)['crowd'] as List) Merchant.fromJson(asMap(m))];
      });

  Future<List<Merchant>> search(String query, {LatLng? near}) => guard(() async {
        final res = await _client.dio.get<dynamic>(
          'merchants/search/',
          queryParameters: {'q': query, ...?near?.coarse.toJson()},
        );
        return [for (final m in asMap(res.data)['merchants'] as List) Merchant.fromJson(asMap(m))];
      });

  Future<ResolveResult> resolveAsPerson(int payeeId) => _resolve(payeeId, {'kind': 'person'});

  Future<ResolveResult> resolveAsMerchant(int payeeId, String merchantId, {LatLng? here}) =>
      _resolve(payeeId, {'kind': 'merchant', 'merchant_id': merchantId, ...?here?.coarse.toJson()});

  Future<ResolveResult> resolveAsNewMerchant(int payeeId, NewMerchant merchant, {LatLng? here}) =>
      _resolve(payeeId, {'kind': 'merchant', 'new_merchant': merchant.toJson(), ...?here?.coarse.toJson()});

  Future<ResolveResult> _resolve(int payeeId, Map<String, dynamic> body) => guard(() async {
        final res = await _client.dio.post<dynamic>('payees/$payeeId/resolve/', data: body);
        return ResolveResult.fromJson(asMap(res.data));
      });
}

class TaggingApi {
  TaggingApi(this._client);
  final ApiClient _client;

  /// Chips for the item screen.
  Future<List<Item>> items({String? category, String? query}) => guard(() async {
        final res = await _client.dio.get<dynamic>('items/', queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (query != null && query.isNotEmpty) 'q': query,
        });
        return [for (final i in asMap(res.data)['items'] as List) Item.fromJson(asMap(i))];
      });

  Future<ItemSuggestions> suggestions(String transactionId) => guard(() async {
        final res = await _client.dio.get<dynamic>('transactions/$transactionId/suggestions/');
        final data = asMap(res.data);
        return ItemSuggestions(
          suggestions: [for (final s in data['suggestions'] as List) ItemSuggestion.fromJson(asMap(s))],
          shouldPrompt: data['should_prompt'] as bool? ?? true,
        );
      });

  /// Replaces the payment's tags with the user's choice.
  Future<List<TaggedItem>> setItems(String transactionId, List<ItemEntry> entries) => guard(() async {
        final res = await _client.dio.put<dynamic>(
          'transactions/$transactionId/items/',
          data: {'items': [for (final e in entries) e.toJson()]},
        );
        return [for (final i in asMap(res.data)['items'] as List) TaggedItem.fromJson(asMap(i))];
      });

  /// The one-tap "Yes, correct".
  Future<List<TaggedItem>> confirmItems(String transactionId) => guard(() async {
        final res = await _client.dio.post<dynamic>('transactions/$transactionId/items/confirm/');
        return [for (final i in asMap(res.data)['items'] as List) TaggedItem.fromJson(asMap(i))];
      });
}
