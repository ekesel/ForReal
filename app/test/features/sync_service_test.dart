import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/sync/sync_service.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';

void main() {
  late TestBackend backend;
  late LocalStore store;
  late DateTime now;
  late FixedLocation location;

  SyncService service({int batchSize = 200}) => SyncService(
        store: store,
        transactions: TransactionsApi(backend.client),
        merchants: MerchantsApi(backend.client),
        tagging: TaggingApi(backend.client),
        location: location,
        now: () => now,
        batchSize: batchSize,
      );

  List<Map<String, dynamic>> sentRows(RecordedRequest r) =>
      [for (final row in r.json['transactions'] as List) Map<String, dynamic>.from(row as Map)];

  /// Accepts every row, like the real endpoint.
  void acceptAll({String? ask = 'payee'}) {
    backend.api.on('POST', 'transactions/batch/', (r) {
      return FakeResponse.ok({
        'results': [for (final row in sentRows(r)) ingestResult(serverTxn(row['client_txn_id'] as String), ask: ask)],
      });
    });
  }

  Future<void> add(String id, {DateTime? at, double amount = 300}) =>
      store.insertParsed(parsed(id, at: at, amount: amount, ref: '4000$id'), fromHistory: false);

  setUp(() {
    backend = TestBackend();
    store = memoryStore();
    now = DateTime(2026, 8, 2, 18, 31);
    location = FixedLocation();
  });
  tearDown(() => store.db.close());

  test('pending rows are uploaded oldest first with only server-safe fields', () async {
    await add('b', at: DateTime(2026, 8, 2, 12));
    await add('a', at: DateTime(2026, 8, 1, 9), amount: 49.99);
    acceptAll();

    final outcome = await service().run();

    expect(outcome.clean, isTrue);
    expect([for (final s in outcome.synced) s.clientTxnId], ['a', 'b']);
    final rows = sentRows(backend.api.requests.single);
    expect(rows.first, {
      'client_txn_id': 'a',
      'payee_name': 'RAMESH  KUMAR',
      'occurred_on': '2026-08-02',
      'day_part': 'morning',
      'amount_band': 'lt_50',
      'source': 'sms',
      'ref': '4000a',
    });
    expect(rows.last['client_txn_id'], 'b');
    expect((await store.get('a'))!.syncState, 'synced');
    expect((await store.get('a'))!.serverId, 's-a');
    expect(await store.pendingCount(), 0);
  });

  test('more than one batch is sent in batches', () async {
    for (var i = 0; i < 5; i++) {
      await add('t$i', at: DateTime(2026, 8, 1, 9, i));
    }
    acceptAll();

    final outcome = await service(batchSize: 2).run();

    final sizes = [for (final r in backend.api.requests) sentRows(r).length];
    expect(sizes, [2, 2, 1]);
    expect(outcome.synced, hasLength(5));
    expect(sentRows(backend.api.requests.first).first['client_txn_id'], 't0');
  });

  test('the default batch is the server limit of 200', () async {
    for (var i = 0; i < 201; i++) {
      await add('t$i', at: DateTime(2026, 8, 1).add(Duration(minutes: i)));
    }
    acceptAll();
    await service().run();
    expect([for (final r in backend.api.requests) sentRows(r).length], [200, 1]);
  });

  test('duplicate and merged count as success', () async {
    await add('a');
    await add('b', at: DateTime(2026, 8, 2, 19));
    backend.api.on('POST', 'transactions/batch/', (r) {
      return FakeResponse.ok({
        'results': [
          ingestResult(serverTxn('a'), status: 'duplicate'),
          ingestResult(serverTxn('b'), status: 'merged', ask: null),
        ],
      });
    });

    final outcome = await service().run();

    expect(outcome.synced, hasLength(2));
    expect((await store.get('a'))!.syncState, 'synced');
    expect((await store.get('b'))!.syncState, 'synced');
    expect((await store.get('b'))!.ask, isNull);
  });

  test('a network error keeps rows pending and asks for a retry', () async {
    await add('a');
    backend.api.on('POST', 'transactions/batch/', (_) => throw const Offline());

    final outcome = await service().run();

    expect(outcome.retryLater, isTrue);
    expect(outcome.synced, isEmpty);
    expect((await store.get('a'))!.syncState, 'pending');
  });

  test('a 5xx keeps rows pending and asks for a retry', () async {
    await add('a');
    backend.api.reply('POST', 'transactions/batch/', {'detail': 'boom'}, status: 502);
    final outcome = await service().run();
    expect(outcome.retryLater, isTrue);
    expect((await store.get('a'))!.syncState, 'pending');
  });

  test('re-sending after a lost response is idempotent', () async {
    await add('a');
    var calls = 0;
    backend.api.on('POST', 'transactions/batch/', (r) {
      calls++;
      // The first upload reached the server but its response was lost.
      if (calls == 1) throw const Offline();
      return FakeResponse.ok({
        'results': [ingestResult(serverTxn('a'), status: 'duplicate')],
      });
    });

    final first = await service().run();
    expect(first.retryLater, isTrue);
    final second = await service().run();

    expect(second.clean, isTrue);
    final ids = [for (final r in backend.api.requests) sentRows(r).single['client_txn_id']];
    expect(ids, ['a', 'a'], reason: 'the same client_txn_id is sent again');
    expect((await store.get('a'))!.syncState, 'synced');
    expect((await store.watchAll().first), hasLength(1));
  });

  test('a rejected row is marked failed with its reason and does not block the rest', () async {
    await add('a', at: DateTime(2026, 8, 1, 9));
    await add('bad', at: DateTime(2026, 8, 1, 10));
    await add('c', at: DateTime(2026, 8, 1, 11));
    backend.api.on('POST', 'transactions/batch/', (r) {
      final rows = sentRows(r);
      if (rows.any((row) => row['client_txn_id'] == 'bad')) {
        return FakeResponse(400, {
          'transactions': [
            for (final row in rows)
              row['client_txn_id'] == 'bad'
                  ? {
                      'occurred_on': ['Date is in the future.']
                    }
                  : <String, dynamic>{},
          ],
        });
      }
      return FakeResponse.ok({
        'results': [for (final row in rows) ingestResult(serverTxn(row['client_txn_id'] as String))],
      });
    });

    final outcome = await service().run();

    expect(outcome.failed, 1);
    expect(outcome.clean, isTrue);
    expect([for (final s in outcome.synced) s.clientTxnId], ['a', 'c']);
    final bad = (await store.get('bad'))!;
    expect(bad.syncState, 'failed');
    expect(bad.error, 'occurred_on: Date is in the future.');
    expect((await store.get('a'))!.syncState, 'synced');
    expect((await store.get('c'))!.syncState, 'synced');
    expect(backend.api.requests, hasLength(2));
  });

  test('per-row errors keyed by index (current DRF) are understood too', () async {
    await add('a', at: DateTime(2026, 8, 1, 9));
    await add('bad', at: DateTime(2026, 8, 1, 10));
    await add('c', at: DateTime(2026, 8, 1, 11));
    backend.api.on('POST', 'transactions/batch/', (r) {
      final rows = sentRows(r);
      final index = rows.indexWhere((row) => row['client_txn_id'] == 'bad');
      if (index >= 0) {
        return FakeResponse(400, {
          'transactions': {
            '$index': {
              'amount_band': ['"zzz" is not a valid choice.']
            }
          },
        });
      }
      return FakeResponse.ok({
        'results': [for (final row in rows) ingestResult(serverTxn(row['client_txn_id'] as String))],
      });
    });

    final outcome = await service().run();

    expect(outcome.failed, 1);
    expect([for (final s in outcome.synced) s.clientTxnId], ['a', 'c']);
    expect((await store.get('bad'))!.error, 'amount_band: "zzz" is not a valid choice.');
    expect(backend.api.requests, hasLength(2), reason: 'no one-by-one fallback needed');
  });

  test('a 400 that does not name the row is narrowed down one row at a time', () async {
    await add('a', at: DateTime(2026, 8, 1, 9));
    await add('bad', at: DateTime(2026, 8, 1, 10));
    backend.api.on('POST', 'transactions/batch/', (r) {
      final rows = sentRows(r);
      if (rows.any((row) => row['client_txn_id'] == 'bad')) {
        return const FakeResponse(400, {'detail': 'Malformed request.'});
      }
      return FakeResponse.ok({
        'results': [for (final row in rows) ingestResult(serverTxn(row['client_txn_id'] as String))],
      });
    });

    final outcome = await service().run();

    expect(outcome.failed, 1);
    expect((await store.get('a'))!.syncState, 'synced');
    expect((await store.get('bad'))!.syncState, 'failed');
    expect((await store.get('bad'))!.error, 'Malformed request.');
  });

  test('a failed row is not sent again until the user retries it', () async {
    await add('bad');
    await store.markFailed('bad', 'nope');
    acceptAll();
    await service().run();
    expect(backend.api.requests, isEmpty);
    await store.retryFailed('bad');
    await service().run();
    expect(backend.api.requests, hasLength(1));
  });

  test('403 stops the sync and reports that consent is required', () async {
    await add('a');
    await add('b', at: DateTime(2026, 8, 2, 19));
    backend.api.reply('POST', 'transactions/batch/',
        {'code': 'consent_required', 'detail': "Grant the 'private_analytics' consent before sending or reading payment data."},
        status: 403);

    final outcome = await service(batchSize: 1).run();

    expect(outcome.consentRequired, isTrue);
    expect(outcome.retryLater, isFalse);
    expect(backend.api.requests, hasLength(1), reason: 'no further batches after a 403');
    expect(await store.pendingCount(), 2);
  });

  test('a 403 without the consent code is an ordinary error: no consent screen, no retry loop', () async {
    await add('a');
    backend.api.reply('POST', 'transactions/batch/', {'detail': 'You do not have permission to perform this action.'},
        status: 403);

    final outcome = await service().run();

    expect(outcome.consentRequired, isFalse);
    expect(outcome.retryLater, isFalse);
    expect(outcome.clean, isFalse);
    expect(outcome.error!.statusCode, 403);
    expect(outcome.error!.message, contains('permission'));
    expect((await store.get('a'))!.syncState, 'pending', reason: 'the row is kept, not marked failed');
    expect(backend.api.requests, hasLength(1));
  });

  test('concurrent runs share one upload', () async {
    await add('a');
    acceptAll();
    final sync = service();
    await Future.wait([sync.run(), sync.run()]);
    expect(backend.api.requests, hasLength(1));
  });

  group('location at ingest', () {
    test('none when there is no fresh foreground fix', () async {
      await add('a', at: now.subtract(const Duration(minutes: 1)));
      acceptAll();
      await service().run();
      final row = sentRows(backend.api.requests.single).single;
      expect(row.containsKey('lat'), isFalse);
      expect(row.containsKey('lng'), isFalse);
    });

    test('a fresh fix is attached, rounded, to a payment that just happened', () async {
      location.recent = const LatLng(28.62804912, 77.36491234);
      await add('a', at: now.subtract(const Duration(minutes: 1)));
      acceptAll();
      await service().run();
      final row = sentRows(backend.api.requests.single).single;
      expect(row['lat'], 28.628);
      expect(row['lng'], 77.365);
    });

    test('never attached to an old payment or a history row', () async {
      location.recent = const LatLng(28.628, 77.365);
      await add('old', at: now.subtract(const Duration(minutes: 11)));
      await store.insertParsed(parsed('hist', at: now.subtract(const Duration(minutes: 1))), fromHistory: true);
      acceptAll();
      await service().run();
      for (final row in sentRows(backend.api.requests.single)) {
        expect(row.containsKey('lat'), isFalse, reason: '${row['client_txn_id']}');
      }
    });
  });

  group('answers given offline from a notification', () {
    setUp(() async {
      await add('a');
      await store.applyIngestResult('a', IngestResult.fromJson(ingestResult(serverTxn('a'))));
    });

    test('are replayed before uploading', () async {
      await store.addPendingAction('a', 'person');
      backend.api.reply('POST', 'payees/7/resolve/', {
        'payee': {'id': 7, 'name': 'X'},
        'kind': 'person',
        'merchant': null,
      });

      final outcome = await service().run();

      expect(outcome.clean, isTrue);
      expect(backend.api.to('POST', 'payees/7/resolve/').single.json, {'kind': 'person'});
      expect(await store.pendingActions(), isEmpty);
      expect((await store.get('a'))!.kind, 'person');
    });

    test('stay queued while offline', () async {
      await store.addPendingAction('a', 'confirm_items');
      backend.api.on('POST', 'transactions/s-a/items/confirm/', (_) => throw const Offline());
      final outcome = await service().run();
      expect(outcome.retryLater, isTrue);
      expect(await store.pendingActions(), hasLength(1));
    });

    test('are dropped when the server refuses them for good', () async {
      await store.addPendingAction('a', 'confirm_items');
      backend.api.reply('POST', 'transactions/s-a/items/confirm/',
          {'code': 'not_taggable', 'detail': 'Payments to a person cannot be tagged.'},
          status: 400);
      final outcome = await service().run();
      expect(outcome.clean, isTrue);
      expect(await store.pendingActions(), isEmpty);
    });
  });

  group('reconcile', () {
    test('uploads, then follows every page of the server list', () async {
      await add('a');
      acceptAll();
      backend.api.on('GET', 'transactions/', (r) {
        if (r.query['cursor'] == 'p2') {
          return FakeResponse.ok({
            'next': null,
            'results': [serverTxn('restored')],
          });
        }
        return FakeResponse.ok({
          'next': '${testBaseUrl}transactions/?cursor=p2',
          'results': [
            serverTxn('a', kind: 'merchant', merchant: teaStall, items: [guess('Tea')])
          ],
        });
      });

      final outcome = await service().reconcile();

      expect(outcome.clean, isTrue);
      final a = (await store.get('a'))!;
      expect(a.kind, 'merchant');
      expect(a.amountExact, 300);
      final restored = (await store.get('restored'))!;
      expect(restored.amountExact, isNull);
      expect(restored.syncState, 'synced');
    });

    test('reports consent required from the list endpoint', () async {
      backend.api.reply('GET', 'transactions/', {'code': 'consent_required', 'detail': 'Grant consent.'}, status: 403);
      final outcome = await service().reconcile();
      expect(outcome.consentRequired, isTrue);
    });
  });

  test('retry delay backs off and is capped', () {
    expect(retryDelay(0), const Duration(seconds: 5));
    expect(retryDelay(1), const Duration(seconds: 10));
    expect(retryDelay(3), const Duration(seconds: 40));
    expect(retryDelay(6), const Duration(seconds: 300));
    expect(retryDelay(50), const Duration(seconds: 300));
  });
}
