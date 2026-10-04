import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/items/items_service.dart';
import 'package:forreal/features/notifications/notification_answers.dart';
import 'package:forreal/features/payee/payee_service.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';

void main() {
  late TestBackend backend;
  late LocalStore store;
  late RecordingNotifier notifier;
  late FixedLocation location;
  late DateTime now;
  late PayeeService payees;
  late ItemsService items;
  late NotificationAnswers answers;

  Future<LocalTransaction> payment(String id, {Duration age = const Duration(minutes: 2), int payee = 7}) async {
    await store.insertParsed(parsed(id, at: now.subtract(age)), fromHistory: false);
    await store.applyIngestResult(id, IngestResult.fromJson(ingestResult(serverTxn(id, payee: payee))));
    return (await store.get(id))!;
  }

  void resolveReplies() {
    backend.api.on('POST', 'payees/7/resolve/', (r) {
      final person = r.json['kind'] == 'person';
      return FakeResponse.ok({
        'payee': {'id': 7, 'name': 'RAMESH  KUMAR'},
        'kind': r.json['kind'],
        'merchant': person ? null : teaStall,
      });
    });
    for (final id in ['a', 'b']) {
      backend.api.reply('GET', 'transactions/s-$id/',
          serverTxn(id, kind: 'merchant', merchant: teaStall, items: [guess('Tea')]));
    }
  }

  setUp(() {
    backend = TestBackend();
    store = memoryStore();
    notifier = RecordingNotifier();
    location = FixedLocation(current: const LatLng(28.62804, 77.36491));
    now = DateTime(2026, 8, 2, 18, 30);
    payees = PayeeService(
      store: store,
      merchants: MerchantsApi(backend.client),
      transactions: TransactionsApi(backend.client),
      location: location,
      notifier: notifier,
      now: () => now,
    );
    items = ItemsService(store: store, tagging: TaggingApi(backend.client), notifier: notifier);
    answers = NotificationAnswers(store: store, payees: payees, items: items);
  });
  tearDown(() => store.db.close());

  group('payee', () {
    test('person applies to every payment to the payee and clears their prompts', () async {
      final a = await payment('a');
      await payment('b');
      await payment('other', payee: 8);
      resolveReplies();

      await payees.markPerson(a);

      expect(backend.api.to('POST', 'payees/7/resolve/').single.json, {'kind': 'person'});
      expect((await store.get('a'))!.kind, 'person');
      expect((await store.get('b'))!.kind, 'person');
      expect((await store.get('other'))!.kind, 'unknown');
      expect(notifier.cancelled.toSet(), {'a', 'b'});
    });

    test('choosing a shop updates all its payments and pulls the server guesses', () async {
      final a = await payment('a');
      await payment('b');
      resolveReplies();

      await payees.chooseMerchant(a, Merchant.fromJson(teaStall));

      for (final id in ['a', 'b']) {
        final row = (await store.get(id))!;
        expect(row.kind, 'merchant');
        expect(row.merchantInfo!.name, 'Sharma Tea Stall');
        expect(row.taggedItems.single.item.name, 'Tea');
        expect(row.state, TxnState.needsItems);
      }
    });

    test('adding a new shop sends name, category and the online flag', () async {
      final a = await payment('a');
      resolveReplies();
      await payees.addMerchant(a, const NewMerchant(name: 'Sharma Tea Stall', category: 'tea-stall'));
      expect(backend.api.to('POST', 'payees/7/resolve/').single.json, {
        'kind': 'merchant',
        'new_merchant': {'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false},
      });
    });

    test('location is used only within 10 minutes of the payment', () async {
      final fresh = await payment('a', age: const Duration(minutes: 9));
      final stale = await payment('b', age: const Duration(minutes: 11));
      expect((await payees.hereFor(fresh))!.coarse.lat, 28.628);
      expect(await payees.hereFor(stale), isNull);
      expect(location.fixes, 1, reason: 'no fix is even requested for an old payment');
    });

    test('with a location, the resolve carries it and the payment gets it', () async {
      final a = await payment('a');
      resolveReplies();
      backend.api.reply('POST', 'transactions/s-a/location/', serverTxn('a'));

      final here = await payees.hereFor(a);
      await payees.chooseMerchant(a, Merchant.fromJson(teaStall), here: here);

      expect(backend.api.to('POST', 'payees/7/resolve/').single.json,
          {'kind': 'merchant', 'merchant_id': 'm-1', 'lat': 28.628, 'lng': 77.365});
      expect(backend.api.to('POST', 'transactions/s-a/location/').single.json, {'lat': 28.628, 'lng': 77.365});
    });

    test('without a location neither call carries or sets one', () async {
      final a = await payment('a', age: const Duration(hours: 2));
      resolveReplies();
      await payees.chooseMerchant(a, Merchant.fromJson(teaStall), here: await payees.hereFor(a));
      expect(backend.api.to('POST', 'payees/7/resolve/').single.json, {'kind': 'merchant', 'merchant_id': 'm-1'});
      expect(backend.api.to('POST', 'transactions/s-a/location/'), isEmpty);
    });

    test('a payment not yet on the server cannot be resolved', () async {
      await store.insertParsed(parsed('local-only'), fromHistory: false);
      final row = (await store.get('local-only'))!;
      await expectLater(payees.markPerson(row), throwsA(isA<ApiException>()));
      expect(backend.api.requests, isEmpty);
    });
  });

  group('items', () {
    final confirmed = {
      'items': [guess('Tea', inferred: false)]
    };

    test('confirm marks the guess as the user answer and clears the prompt', () async {
      final a = await payment('a');
      backend.api.reply('POST', 'transactions/s-a/items/confirm/', confirmed);
      await items.confirm(a);
      final row = (await store.get('a'))!;
      expect(row.taggedItems.single.inferred, isFalse);
      expect(row.ask, isNull);
      expect(notifier.cancelled, ['a']);
    });

    test('save replaces the tags', () async {
      final a = await payment('a');
      backend.api.reply('PUT', 'transactions/s-a/items/', confirmed);
      await items.save(a, const [ItemEntry.catalogue(3, 2), ItemEntry.named('samosa', 1)]);
      expect(backend.api.requests.single.json['items'], hasLength(2));
      expect((await store.get('a'))!.taggedItems.single.item.name, 'Tea');
    });

    test('chips are requested for the shop category', () async {
      final a = await payment('a');
      await store.applyPayeeResolution(7, kind: 'merchant', merchant: Merchant.fromJson(teaStall));
      backend.api.reply('GET', 'items/', {'items': []});
      await items.chips((await store.get('a'))!);
      expect(backend.api.requests.single.query, {'category': 'tea-stall'});
      expect(a.kind, 'unknown');
    });
  });

  group('notification buttons', () {
    test('[Person] resolves on the server and updates the local row', () async {
      await payment('a');
      resolveReplies();
      await answers.person('a');
      expect((await store.get('a'))!.kind, 'person');
      expect(await store.pendingActions(), isEmpty);
    });

    test('[Person] offline is applied locally and queued for the next sync', () async {
      await payment('a');
      backend.api.on('POST', 'payees/7/resolve/', (_) => throw const Offline());
      await answers.person('a');
      expect((await store.get('a'))!.kind, 'person');
      final queued = (await store.pendingActions()).single;
      expect(queued.type, 'person');
      expect(queued.clientTxnId, 'a');
    });

    test('[Yes] confirms the guessed items', () async {
      await payment('a');
      backend.api.reply('POST', 'transactions/s-a/items/confirm/', {
        'items': [guess('Tea', inferred: false)]
      });
      await answers.confirmItems('a');
      expect((await store.get('a'))!.taggedItems.single.inferred, isFalse);
    });

    test('[Yes] offline keeps the answer and queues it', () async {
      await payment('a');
      await store.applyPayeeResolution(7, kind: 'merchant', merchant: Merchant.fromJson(teaStall));
      await store.setItems('a', [TaggedItem.fromJson(guess('Tea'))]);
      backend.api.on('POST', 'transactions/s-a/items/confirm/', (_) => throw const Offline());
      await answers.confirmItems('a');
      final row = (await store.get('a'))!;
      expect(row.taggedItems.single.inferred, isFalse);
      expect(row.state, TxnState.done);
      expect((await store.pendingActions()).single.type, 'confirm_items');
    });

    test('the answer is on disk before the network call, so a killed isolate loses nothing', () async {
      await payment('a');
      late List<String> queuedDuringCall;
      late String kindDuringCall;
      backend.api.on('POST', 'payees/7/resolve/', (r) async {
        queuedDuringCall = [for (final a in await store.pendingActions()) a.type];
        kindDuringCall = (await store.get('a'))!.kind;
        return const FakeResponse.ok({
          'payee': {'id': 7, 'name': 'X'},
          'kind': 'person',
          'merchant': null,
        });
      });
      await answers.person('a');
      expect(queuedDuringCall, ['person']);
      expect(kindDuringCall, 'person');
      expect(await store.pendingActions(), isEmpty, reason: 'cleared once the server confirmed');
    });

    test('an answer the server refuses for good is not queued', () async {
      await payment('a');
      await store.applyPayeeResolution(7, kind: 'merchant', merchant: Merchant.fromJson(teaStall));
      await store.setItems('a', [TaggedItem.fromJson(guess('Tea'))]);
      backend.api.reply('POST', 'transactions/s-a/items/confirm/', {'code': 'not_taggable', 'detail': 'x'}, status: 400);
      await answers.confirmItems('a');
      expect(await store.pendingActions(), isEmpty);
      expect((await store.get('a'))!.taggedItems.single.inferred, isTrue, reason: 'the optimistic change is undone');
    });

    test('a notification for a payment that no longer exists does nothing', () async {
      await answers.person('gone');
      await answers.confirmItems('gone');
      expect(backend.api.requests, isEmpty);
    });
  });
}
