import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/models.dart';

import '../support/fake_api.dart';

Map<String, dynamic> txn({String id = 's-1', String client = 'c-1', String kind = 'unknown'}) => {
      'id': id,
      'client_txn_id': client,
      'payee': {'id': 7, 'name': 'RAMESH  KUMAR'},
      'merchant': null,
      'kind': kind,
      'occurred_on': '2026-08-02',
      'day_part': 'evening',
      'amount_band': '200_500',
      'sources': ['sms'],
      'location': null,
      'items': [],
      'created_at': '2026-08-02T13:00:00Z',
    };

const shop = {'id': 'm-1', 'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false, 'location': null};
const tea = {'id': 3, 'name': 'Tea', 'category': 'tea-stall'};

/// Field names the ingest API refuses (backend/apps/transactions/serializers.py).
const forbidden = {'amount', 'raw_text', 'sms_body', 'body', 'message', 'balance', 'account', 'account_last4', 'vpa'};

void main() {
  late TestBackend backend;
  setUp(() => backend = TestBackend());

  group('auth', () {
    test('request OTP returns the debug code when the backend echoes it', () async {
      backend.api.reply('POST', 'auth/otp/request/', {'detail': 'Code sent.', 'expires_in': 300, 'debug_code': '123456'});
      final result = await AuthApi(backend.client, backend.tokens).requestOtp('9876543210');
      expect(result.debugCode, '123456');
      expect(result.expiresIn, 300);
      final sent = backend.api.requests.single;
      expect(sent.json, {'phone': '9876543210'});
      expect(sent.bearer, isNull);
    });

    test('too many OTP requests is a 429 with the backend code', () async {
      backend.api.reply('POST', 'auth/otp/request/',
          {'code': 'too_many_requests', 'detail': 'Too many codes requested. Try again later.'},
          status: 429);
      await expectLater(
        AuthApi(backend.client, backend.tokens).requestOtp('9876543210'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'too_many_requests')
            .having((e) => e.isRateLimited, 'rate limited', isTrue)
            .having((e) => e.message, 'message', contains('Too many codes'))),
      );
    });

    test('the DRF throttle is a 429 without a code', () async {
      backend.api.reply('POST', 'auth/otp/request/', {'detail': 'Request was throttled. Expected available in 60 seconds.'},
          status: 429);
      await expectLater(
        AuthApi(backend.client, backend.tokens).requestOtp('9876543210'),
        throwsA(isA<ApiException>().having((e) => e.isRateLimited, 'rate limited', isTrue).having((e) => e.code, 'code', isNull)),
      );
    });

    test('verify stores the tokens', () async {
      backend = TestBackend(signedIn: false);
      backend.api.reply('POST', 'auth/otp/verify/', {
        'access': 'a',
        'refresh': 'r',
        'is_new_user': true,
        'user': {'id': 'u-1', 'phone': '+919876543210', 'display_name': '', 'created_at': '2026-08-01T00:00:00Z'},
      });
      final session = await AuthApi(backend.client, backend.tokens).verifyOtp('+919876543210', '123456');
      expect(session.isNewUser, isTrue);
      expect(session.user.phone, '+919876543210');
      expect((await backend.tokens.load())!.refresh, 'r');
      expect(backend.api.requests.single.json, {'phone': '+919876543210', 'code': '123456'});
    });

    test('a wrong code carries the backend code', () async {
      backend.api.reply('POST', 'auth/otp/verify/', {'code': 'invalid', 'detail': 'Incorrect code.'}, status: 400);
      await expectLater(
        AuthApi(backend.client, backend.tokens).verifyOtp('+919876543210', '000000'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid')),
      );
    });

    test('a field validation error is readable', () async {
      backend.api.reply('POST', 'auth/otp/request/', {
        'phone': ['Phone must be in E.164 format, e.g. +919876543210.']
      }, status: 400);
      await expectLater(
        AuthApi(backend.client, backend.tokens).requestOtp('12'),
        throwsA(isA<ApiException>()
            .having((e) => e.fieldErrors['phone'], 'field', contains('E.164'))
            .having((e) => e.message, 'message', contains('E.164'))),
      );
    });
  });

  group('account', () {
    test('device registration sends the install id, android and an empty push token', () async {
      backend.api.reply('PUT', 'me/device/', {'device_id': 'abc'});
      await AccountApi(backend.client).registerDevice(deviceId: 'abc', appVersion: '0.1.0');
      expect(backend.api.requests.single.json,
          {'device_id': 'abc', 'platform': 'android', 'app_version': '0.1.0', 'push_token': ''});
    });

    test('export, delete and display name', () async {
      backend.api.reply('GET', 'me/export/', {'user': {'phone': '+91'}, 'transactions': []});
      backend.api.reply('DELETE', 'me/', null, status: 204);
      backend.api.reply('PATCH', 'me/', {'id': 'u', 'phone': '+91', 'display_name': 'Asha'});
      final api = AccountApi(backend.client);
      expect((await api.export())['transactions'], isEmpty);
      await api.deleteAccount();
      expect((await api.setDisplayName('Asha')).displayName, 'Asha');
      expect(backend.api.to('PATCH', 'me/').single.json, {'display_name': 'Asha'});
    });
  });

  group('consents', () {
    const state = {
      'private_analytics': true,
      'community_rankings': false,
      'show_name': false,
      'location': true,
      'merchant_insights': false,
    };

    test('current state', () async {
      backend.api.reply('GET', 'consents/', {'consents': state});
      final consents = await ConsentApi(backend.client).current();
      expect(consents.has(Purpose.privateAnalytics), isTrue);
      expect(consents.has(Purpose.location), isTrue);
      expect(consents.has(Purpose.communityRankings), isFalse);
    });

    test('a change posts purpose, granted and the notice version', () async {
      backend.api.reply('POST', 'consents/', {'consents': state});
      await ConsentApi(backend.client).set(Purpose.location, granted: true, noticeVersion: 'v1');
      expect(backend.api.requests.single.json, {'purpose': 'location', 'granted': true, 'notice_version': 'v1'});
    });

    test('a missing parent consent is reported as "dependency"', () async {
      backend.api.reply('POST', 'consents/',
          {'code': 'dependency', 'detail': "'show_name' needs 'community_rankings' to be granted first."},
          status: 400);
      await expectLater(
        ConsentApi(backend.client).set(Purpose.showName, granted: true, noticeVersion: 'v1'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'dependency')),
      );
    });
  });

  group('parser templates', () {
    test('first download has no version parameter', () async {
      backend.api.reply('GET', 'parser-templates/', {
        'version': 12,
        'changed': true,
        'templates': [
          {'id': 1, 'bank': 'HDFC', 'sender_ids': ['HDFCBK'], 'pattern': 'x'}
        ],
      });
      final res = await TemplatesApi(backend.client).fetch();
      expect(res.changed, isTrue);
      expect(res.version, 12);
      expect(res.templates.single['bank'], 'HDFC');
      expect(backend.api.requests.single.query, isEmpty);
    });

    test('unchanged', () async {
      backend.api.reply('GET', 'parser-templates/', {'version': 12, 'changed': false});
      final res = await TemplatesApi(backend.client).fetch(knownVersion: 12);
      expect(res.changed, isFalse);
      expect(res.templates, isEmpty);
      expect(backend.api.requests.single.query, {'version': '12'});
    });
  });

  group('transactions', () {
    test('ingest sends only fields the server may hold', () async {
      backend.api.reply('POST', 'transactions/batch/', {
        'results': [
          {'status': 'created', 'transaction': txn(), 'ask': 'payee', 'payee_suggestions': [shop]},
        ],
      });
      final results = await TransactionsApi(backend.client).ingest([
        const IngestRow(
          clientTxnId: 'c-1',
          payeeName: 'RAMESH  KUMAR',
          occurredOn: '2026-08-02',
          dayPart: 'evening',
          amountBand: '200_500',
          ref: '400012345678',
        ),
      ]);
      expect(results.single.status, 'created');
      expect(results.single.ask, 'payee');
      expect(results.single.transaction.payee.id, 7);
      expect(results.single.payeeSuggestions.single.name, 'Sharma Tea Stall');

      final row = (backend.api.requests.single.json['transactions'] as List).single as Map;
      expect(row, {
        'client_txn_id': 'c-1',
        'payee_name': 'RAMESH  KUMAR',
        'occurred_on': '2026-08-02',
        'day_part': 'evening',
        'amount_band': '200_500',
        'source': 'sms',
        'ref': '400012345678',
      });
      expect(row.keys.toSet().intersection(forbidden), isEmpty);
    });

    test('a location is rounded to about 110 m before it is sent', () {
      const row = IngestRow(
        clientTxnId: 'c',
        payeeName: 'P',
        occurredOn: '2026-08-02',
        dayPart: '',
        amountBand: 'lt_50',
        location: LatLng(28.628049123, 77.364912345),
      );
      final json = row.toJson();
      expect(json['lat'], 28.628);
      expect(json['lng'], 77.365);
      expect(json.containsKey('day_part'), isFalse);
      expect(json.containsKey('ref'), isFalse);
    });

    test('list follows the cursor', () async {
      backend.api.on('GET', 'transactions/', (r) {
        return r.query['cursor'] == 'abc'
            ? FakeResponse.ok({'next': null, 'previous': null, 'results': [txn(id: 's-2', client: 'c-2')]})
            : FakeResponse.ok({
                'next': '${testBaseUrl}transactions/?cursor=abc',
                'previous': null,
                'results': [txn()],
              });
      });
      final api = TransactionsApi(backend.client);
      final first = await api.list();
      expect(first.results.single.id, 's-1');
      final second = await api.list(next: first.next);
      expect(second.results.single.id, 's-2');
      expect(second.next, isNull);
    });

    test('detail and location', () async {
      backend.api.reply('GET', 'transactions/s-1/', txn(kind: 'person'));
      backend.api.reply('POST', 'transactions/s-1/location/', {...txn(), 'location': {'lat': 28.628, 'lng': 77.365}});
      final api = TransactionsApi(backend.client);
      expect((await api.get('s-1')).kind, 'person');
      final updated = await api.setLocation('s-1', const LatLng(28.62804, 77.36491));
      expect(updated.hasLocation, isTrue);
      expect(backend.api.to('POST', 'transactions/s-1/location/').single.json, {'lat': 28.628, 'lng': 77.365});
    });

    test('a missing consent is a 403', () async {
      backend.api.reply('POST', 'transactions/batch/',
          {'code': 'consent_required', 'detail': "Grant the 'private_analytics' consent before sending or reading payment data."},
          status: 403);
      await expectLater(
        TransactionsApi(backend.client).ingest(const [
          IngestRow(clientTxnId: 'c', payeeName: 'P', occurredOn: '2026-08-02', dayPart: '', amountBand: 'lt_50'),
        ]),
        throwsA(isA<ApiException>().having((e) => e.isConsentRequired, 'consent', isTrue)),
      );
    });
  });

  group('merchants', () {
    test('categories', () async {
      backend.api.reply('GET', 'categories/', {
        'categories': [
          {'slug': 'bakery', 'name': 'Bakery'}
        ]
      });
      expect((await MerchantsApi(backend.client).categories()).single.slug, 'bakery');
    });

    test('suggestions with and without a location', () async {
      backend.api.reply('GET', 'payees/7/suggestions/', {
        'payee': {'id': 7, 'name': 'X'},
        'crowd': [shop]
      });
      final api = MerchantsApi(backend.client);
      expect((await api.suggestions(7)).single.id, 'm-1');
      await api.suggestions(7, near: const LatLng(28.62804, 77.36491));
      expect(backend.api.requests.first.query, isEmpty);
      expect(backend.api.requests.last.query, {'lat': '28.628', 'lng': '77.365'});
    });

    test('search', () async {
      backend.api.reply('GET', 'merchants/search/', {'merchants': [shop]});
      final found = await MerchantsApi(backend.client).search('sharma', near: const LatLng(28.628, 77.365));
      expect(found.single.category, 'tea-stall');
      expect(backend.api.requests.single.query, {'q': 'sharma', 'lat': '28.628', 'lng': '77.365'});
    });

    test('resolve as person, existing shop and new shop', () async {
      backend.api.on('POST', 'payees/7/resolve/', (r) {
        final person = r.json['kind'] == 'person';
        return FakeResponse.ok({
          'payee': {'id': 7, 'name': 'X'},
          'kind': r.json['kind'],
          'merchant': person ? null : shop,
        });
      });
      final api = MerchantsApi(backend.client);

      final person = await api.resolveAsPerson(7);
      expect(person.kind, 'person');
      expect(person.merchant, isNull);
      expect(backend.api.requests.last.json, {'kind': 'person'});

      final existing = await api.resolveAsMerchant(7, 'm-1', here: const LatLng(28.6281, 77.3649));
      expect(existing.merchant!.name, 'Sharma Tea Stall');
      expect(backend.api.requests.last.json, {'kind': 'merchant', 'merchant_id': 'm-1', 'lat': 28.628, 'lng': 77.365});

      await api.resolveAsNewMerchant(7, const NewMerchant(name: 'Sharma Tea Stall', category: 'tea-stall'));
      expect(backend.api.requests.last.json, {
        'kind': 'merchant',
        'new_merchant': {'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false},
      });
    });
  });

  group('tagging', () {
    final tagged = {
      'items': [
        {'item': tea, 'quantity': 2, 'origin': 'user', 'confidence': 1.0, 'inferred': false}
      ]
    };

    test('item chips by category and query', () async {
      backend.api.reply('GET', 'items/', {'items': [tea]});
      final items = await TaggingApi(backend.client).items(category: 'tea-stall', query: 'te');
      expect(items.single.name, 'Tea');
      expect(backend.api.requests.single.query, {'category': 'tea-stall', 'q': 'te'});
    });

    test('suggestions', () async {
      backend.api.reply('GET', 'transactions/s-1/suggestions/', {
        'suggestions': [
          {'item': tea, 'quantity': 1, 'origin': 'ai_category', 'confidence': 0.5}
        ],
        'should_prompt': true,
      });
      final s = await TaggingApi(backend.client).suggestions('s-1');
      expect(s.shouldPrompt, isTrue);
      expect(s.suggestions.single.item.id, 3);
    });

    test('set items sends ids or names with quantities', () async {
      backend.api.reply('PUT', 'transactions/s-1/items/', tagged);
      final items = await TaggingApi(backend.client)
          .setItems('s-1', const [ItemEntry.catalogue(3, 2), ItemEntry.named('samosa', 1)]);
      expect(items.single.quantity, 2);
      expect(items.single.inferred, isFalse);
      expect(backend.api.requests.single.json, {
        'items': [
          {'item_id': 3, 'quantity': 2},
          {'name': 'samosa', 'quantity': 1},
        ]
      });
    });

    test('confirm', () async {
      backend.api.reply('POST', 'transactions/s-1/items/confirm/', tagged);
      expect((await TaggingApi(backend.client).confirmItems('s-1')).single.item.name, 'Tea');
    });

    test('a payment to a person cannot be tagged', () async {
      backend.api.reply('POST', 'transactions/s-1/items/confirm/',
          {'code': 'not_taggable', 'detail': 'Payments to a person cannot be tagged.'},
          status: 400);
      await expectLater(
        TaggingApi(backend.client).confirmItems('s-1'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_taggable')),
      );
    });
  });

  test('only the consent_required code means the consent is missing', () {
    const consent = ApiException(statusCode: 403, code: 'consent_required', message: 'x');
    expect(consent.isConsentRequired, isTrue);
    for (final other in const [
      ApiException(statusCode: 403, message: 'You do not have permission to perform this action.'),
      ApiException(statusCode: 403, code: 'location_consent_required', message: 'x'),
      ApiException(statusCode: 403, code: 'inactive', message: 'x'),
      ApiException(statusCode: 400, code: 'consent_required', message: 'x'),
    ]) {
      expect(other.isConsentRequired, isFalse, reason: '$other');
      expect(other.isRetryable, isFalse);
    }
  });

  test('no connection is a network error on any repository', () async {
    backend.api.on('GET', 'categories/', (_) => throw const Offline());
    await expectLater(
      MerchantsApi(backend.client).categories(),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', isTrue).having((e) => e.isRetryable, 'retry', isTrue)),
    );
  });
}
