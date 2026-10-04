import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/parser.dart';
import 'package:forreal/capture/raw_message.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';

ParsedPayment payment(String id, {double amount = 300, DateTime? at, String payee = 'RAMESH  KUMAR', String ref = ''}) =>
    ParsedPayment(
      clientTxnId: id,
      bank: 'HDFC',
      payeeName: payee,
      amount: amount,
      occurredOn: DateTime(2026, 8, 2),
      receivedAt: at ?? DateTime(2026, 8, 2, 18, 30),
      ref: ref,
    );

Map<String, dynamic> serverTxn(String id, String clientId,
        {String kind = 'unknown', Map<String, dynamic>? merchant, List<Map<String, dynamic>> items = const [], int payee = 7}) =>
    {
      'id': id,
      'client_txn_id': clientId,
      'payee': {'id': payee, 'name': 'RAMESH  KUMAR'},
      'merchant': merchant,
      'kind': kind,
      'occurred_on': '2026-08-02',
      'day_part': 'evening',
      'amount_band': '200_500',
      'sources': ['sms'],
      'location': null,
      'items': items,
      'created_at': '2026-08-02T13:00:00Z',
    };

Map<String, dynamic> tag(String name, {bool inferred = true}) => {
      'item': {'id': name.hashCode & 0xffff, 'name': name, 'category': 'tea-stall'},
      'quantity': 1,
      'origin': inferred ? 'ai_category' : 'user',
      'confidence': inferred ? 0.5 : 1.0,
      'inferred': inferred,
    };

const teaStall = {'id': 'm-1', 'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false, 'location': null};

IngestResult result(Map<String, dynamic> txn, {String status = 'created', String? ask = 'payee'}) =>
    IngestResult.fromJson({'status': status, 'transaction': txn, 'ask': ask, 'payee_suggestions': []});

void main() {
  late AppDatabase db;
  late LocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(db);
  });
  tearDown(() => db.close());

  test('a parsed payment is stored once, with derived fields and no message text', () async {
    expect(await store.insertParsed(payment('a', amount: 55), fromHistory: false), isTrue);
    expect(await store.insertParsed(payment('a', amount: 55), fromHistory: false), isFalse);
    final row = (await store.get('a'))!;
    expect(row.amountExact, 55);
    expect(row.amountBand, '50_200');
    expect(row.dayPart, 'evening');
    expect(row.occurredOn, '2026-08-02');
    expect(row.syncState, 'pending');
    expect(row.kind, 'unknown');
    expect(row.payeeName, 'RAMESH  KUMAR');
    expect(row.payeeDisplay, 'RAMESH KUMAR');
    expect(row.state, TxnState.needsShop);
  });

  test('pending rows come oldest first and respect the limit', () async {
    await store.insertParsed(payment('new', at: DateTime(2026, 8, 3)), fromHistory: false);
    await store.insertParsed(payment('old', at: DateTime(2026, 8, 1)), fromHistory: false);
    await store.insertParsed(payment('mid', at: DateTime(2026, 8, 2)), fromHistory: false);
    expect([for (final r in await store.pending()) r.clientTxnId], ['old', 'mid', 'new']);
    expect([for (final r in await store.pending(limit: 2)) r.clientTxnId], ['old', 'mid']);
    expect(await store.pendingCount(), 3);
  });

  test('the server response is stored on the row', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    final applied = await store.applyIngestResult(
      'a',
      result(serverTxn('s-1', 'a', kind: 'merchant', merchant: teaStall, items: [tag('Tea')]), ask: 'items'),
    );
    expect(applied.mergedIntoExisting, isFalse);
    final row = (await store.get('a'))!;
    expect(row.syncState, 'synced');
    expect(row.serverId, 's-1');
    expect(row.payeeId, 7);
    expect(row.kind, 'merchant');
    expect(row.merchantInfo!.name, 'Sharma Tea Stall');
    expect(row.taggedItems.single.item.name, 'Tea');
    expect(row.ask, 'items');
    expect(row.title, 'Sharma Tea Stall');
    expect(row.state, TxnState.needsItems);
    expect(await store.pending(), isEmpty);
  });

  test('a row the server merged into an existing payment is dropped', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    await store.applyIngestResult('a', result(serverTxn('s-1', 'a')));
    await store.insertParsed(payment('b'), fromHistory: true);
    final applied = await store.applyIngestResult('b', result(serverTxn('s-1', 'a'), status: 'merged'));
    expect(applied.mergedIntoExisting, isTrue);
    expect(applied.clientTxnId, 'a');
    expect(await store.get('b'), isNull);
    expect((await store.get('a'))!.serverId, 's-1');
  });

  test('failed rows keep their error and can be retried', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    await store.markFailed('a', 'Date is in the future.');
    var row = (await store.get('a'))!;
    expect(row.syncState, 'failed');
    expect(row.error, 'Date is in the future.');
    expect(await store.pending(), isEmpty);
    await store.retryFailed('a');
    row = (await store.get('a'))!;
    expect(row.syncState, 'pending');
    expect(row.error, isNull);
  });

  test('state follows kind, tags and what the server asks', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    Future<TxnState> stateAfter(Map<String, dynamic> txn, String? ask) async {
      await store.applyIngestResult('a', result(txn, ask: ask));
      return (await store.get('a'))!.state;
    }

    expect(await stateAfter(serverTxn('s', 'a'), 'payee'), TxnState.needsShop);
    expect(await stateAfter(serverTxn('s', 'a', kind: 'person'), null), TxnState.person);
    expect(await stateAfter(serverTxn('s', 'a', kind: 'merchant', merchant: teaStall), 'items'), TxnState.needsItems);
    expect(
      await stateAfter(serverTxn('s', 'a', kind: 'merchant', merchant: teaStall, items: [tag('Tea')]), 'items'),
      TxnState.needsItems,
    );
    expect(
      await stateAfter(serverTxn('s', 'a', kind: 'merchant', merchant: teaStall, items: [tag('Tea')]), null),
      TxnState.done,
      reason: 'the server stopped asking: the shop item is learned',
    );
    expect(
      await stateAfter(
          serverTxn('s', 'a', kind: 'merchant', merchant: teaStall, items: [tag('Tea', inferred: false)]), null),
      TxnState.done,
    );
  });

  test('a payee answer applies to all payments to that payee', () async {
    for (final id in ['a', 'b']) {
      await store.insertParsed(payment(id), fromHistory: false);
      await store.applyIngestResult(id, result(serverTxn('s-$id', id)));
    }
    await store.insertParsed(payment('c'), fromHistory: false);
    await store.applyIngestResult('c', result(serverTxn('s-c', 'c', payee: 99)));

    await store.applyPayeeResolution(7, kind: 'merchant', merchant: Merchant.fromJson(teaStall));
    expect((await store.get('a'))!.kind, 'merchant');
    expect((await store.get('b'))!.merchantInfo!.id, 'm-1');
    expect((await store.get('b'))!.ask, 'items');
    expect((await store.get('c'))!.kind, 'unknown');

    await store.setItems('a', [TaggedItem.fromJson(tag('Tea'))]);
    await store.applyPayeeResolution(7, kind: 'person');
    final a = (await store.get('a'))!;
    expect(a.kind, 'person');
    expect(a.merchant, isNull);
    expect(a.taggedItems, isEmpty);
    expect(a.ask, isNull);
  });

  test('saving user items clears the prompt; guesses keep it', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    await store.applyIngestResult('a', result(serverTxn('s', 'a', kind: 'merchant', merchant: teaStall), ask: 'items'));
    await store.setItems('a', [TaggedItem.fromJson(tag('Tea'))]);
    expect((await store.get('a'))!.ask, 'items');
    await store.setItems('a', [TaggedItem.fromJson(tag('Tea', inferred: false))]);
    expect((await store.get('a'))!.ask, isNull);
    expect((await store.get('a'))!.state, TxnState.done);
  });

  test('reconciling updates known rows and restores unknown ones without an amount', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    await store.upsertFromServer(
        ServerTransaction.fromJson(serverTxn('s-a', 'a', kind: 'merchant', merchant: teaStall, items: [tag('Tea')])));
    final a = (await store.get('a'))!;
    expect(a.syncState, 'synced');
    expect(a.amountExact, 300, reason: 'the exact amount is local and untouched');
    expect(a.kind, 'merchant');

    await store.upsertFromServer(ServerTransaction.fromJson(serverTxn('s-z', 'z')));
    final z = (await store.get('z'))!;
    expect(z.amountExact, isNull);
    expect(z.amountBand, '200_500');
    expect(z.ask, 'payee');
    expect(z.notified, isTrue, reason: 'restored rows never notify');
    expect(z.fromHistory, isTrue);
  });

  test('a notification can be claimed exactly once', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    expect(await store.claimNotification('a'), isTrue);
    expect(await store.claimNotification('a'), isFalse);
    expect(await store.claimNotification('missing'), isFalse);
  });

  test('unparsed messages are capped at the newest 200', () async {
    for (var i = 0; i < 205; i++) {
      await store.addUnparsed(RawMessage(
        sender: 'AD-HDFCBK',
        receivedAt: DateTime(2026, 8, 1).add(Duration(minutes: i)),
        body: 'message $i',
      ));
    }
    expect(await store.unparsedCount(), 200);
    final rows = await store.watchUnparsed().first;
    expect(rows.first.body, 'message 204');
    expect(rows.last.body, 'message 5');
  });

  test('templates and their version are cached', () async {
    expect(await store.templatesVersion(), isNull);
    await store.saveTemplates(42, [
      {'id': 1, 'bank': 'HDFC', 'sender_ids': ['HDFCBK'], 'pattern': r'Sent (?<amount>\d+) to (?<payee>\w+)'},
    ]);
    expect(await store.templatesVersion(), 42);
    expect((await store.loadTemplates()).single.bank, 'HDFC');
    await store.saveTemplates(43, []);
    expect(await store.loadTemplates(), isEmpty);
  });

  test('wiping captured data keeps templates; wiping all removes everything', () async {
    await store.insertParsed(payment('a'), fromHistory: false);
    await store.addUnparsed(RawMessage(sender: 'HDFCBK', receivedAt: DateTime(2026), body: 'x'));
    await store.addPendingAction('a', 'person');
    await store.saveTemplates(1, [
      {'id': 1, 'sender_ids': ['HDFCBK'], 'pattern': r'(?<amount>\d+)(?<payee>\w+)'},
    ]);
    await store.takePromptSlot('2026-8-2', 6);
    await store.setSetting(SettingKeys.onboardingDone, '1');

    await store.wipeCaptured();
    expect(await store.get('a'), isNull);
    expect(await store.unparsedCount(), 0);
    expect(await store.pendingActions(), isEmpty);
    expect(await store.getSetting('${SettingKeys.promptCountPrefix}2026-8-2'), isNull);
    expect(await store.getSetting(SettingKeys.onboardingDone), '1');
    expect(await store.loadTemplates(), hasLength(1));

    await store.wipeAll();
    expect(await store.loadTemplates(), isEmpty);
    expect(await store.getSetting(SettingKeys.onboardingDone), isNull);
  });
}
