// End-to-end check of the Dart capture → sync → answer path against a REAL backend.
//
// Skipped unless LIVE_API_BASE_URL is set, for example:
//   LIVE_API_BASE_URL=http://localhost:8000 flutter test test/integration/live_backend_test.dart
// The backend must run with OTP_ECHO_IN_RESPONSE=1. The test creates a throwaway
// user and deletes the account at the end. LIVE_API_HOST_HEADER overrides the Host
// header when the backend is reached through an address not in ALLOWED_HOSTS.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/capture_pipeline.dart';
import 'package:forreal/capture/template_sync.dart';
import 'package:forreal/data/api/api_client.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/data/secret_store.dart';
import 'package:forreal/features/consent/notices.dart';
import 'package:forreal/features/items/items_service.dart';
import 'package:forreal/features/payee/payee_service.dart';
import 'package:forreal/features/sync/sync_service.dart';

import '../support/fakes.dart';

void main() {
  final base = Platform.environment['LIVE_API_BASE_URL'];
  final hostHeader = Platform.environment['LIVE_API_HOST_HEADER'];

  test('a bank SMS becomes a server transaction, resolved to a shop and tagged', () async {
    final root = '${base!.replaceAll(RegExp(r'/+$'), '')}/api/v1/';
    final tokens = TokenStore(MemorySecretStore());
    final client = ApiClient(baseUrl: root, tokens: tokens);
    if (hostHeader != null) {
      client.dio.options.headers['Host'] = hostHeader;
      client.anonymous.options.headers['Host'] = hostHeader;
    }
    final store = memoryStore();
    final source = FakeSource();
    addTearDown(store.db.close);

    final auth = AuthApi(client, tokens);
    final account = AccountApi(client);
    final consents = ConsentApi(client);
    final transactions = TransactionsApi(client);
    final merchants = MerchantsApi(client);
    final tagging = TaggingApi(client);
    final templates = TemplateSync(api: TemplatesApi(client), store: store, control: source);
    final pipeline = CapturePipeline(source: source, store: store, templates: templates);
    final location = FixedLocation(current: const LatLng(28.62804, 77.36491));
    final sync = SyncService(store: store, transactions: transactions, merchants: merchants, tagging: tagging);
    final payees = PayeeService(store: store, merchants: merchants, transactions: transactions, location: location);
    final items = ItemsService(store: store, tagging: tagging);

    // --- sign in -------------------------------------------------------------
    final random = Random();
    final phone = '+9197${List.generate(8, (_) => random.nextInt(10)).join()}';
    final otp = await auth.requestOtp(phone);
    expect(otp.debugCode, isNotNull, reason: 'the backend must run with OTP_ECHO_IN_RESPONSE=1');
    await expectLater(
      auth.verifyOtp(phone, otp.debugCode == '000000' ? '111111' : '000000'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid')),
    );
    final session = await auth.verifyOtp(phone, otp.debugCode!);
    expect(session.isNewUser, isTrue);
    await account.registerDevice(deviceId: await InstallIdStore(MemorySecretStore()).id(), appVersion: '0.1.0');

    var deleted = false;
    addTearDown(() async {
      if (!deleted) await account.deleteAccount();
    });

    // --- consent gates ---------------------------------------------------------
    expect((await consents.current()).has(Purpose.privateAnalytics), isFalse);
    await expectLater(
      consents.set(Purpose.showName, granted: true, noticeVersion: noticeVersion),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'dependency')),
    );
    await expectLater(
      transactions.list(),
      throwsA(isA<ApiException>().having((e) => e.isConsentRequired, 'consent required', isTrue)),
    );

    // Before consent, a pending row makes the sync stop with "consent required".
    await store.insertParsed(parsed('00000000-0000-5000-8000-000000000001', at: DateTime.now()), fromHistory: false);
    expect((await sync.run()).consentRequired, isTrue);
    await store.wipeCaptured();

    var state = await consents.set(Purpose.privateAnalytics, granted: true, noticeVersion: noticeVersion);
    state = await consents.set(Purpose.location, granted: true, noticeVersion: noticeVersion);
    expect(state.has(Purpose.location), isTrue);
    await store.setSetting(SettingKeys.consents, state.encode());

    // --- templates: the seeded HDFC template drives the sender filter ---------------
    final parser = await templates.sync();
    expect(parser.senderCodes, contains('HDFCBK'));
    expect(source.allowedSenders, contains('HDFCBK'));

    // --- first payment: unknown payee --------------------------------------------
    final today = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final on = '${two(today.day)}/${two(today.month)}/${two(today.year % 100)}';
    final payee = 'LIVE TEST  PAYEE ${random.nextInt(1 << 30)}';
    String sms(String amount, String ref) => 'Sent Rs.$amount\nFrom HDFC Bank A/C *1234\nTo $payee\nOn $on\nRef $ref\n'
        'Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808';

    source.enqueue('AD-HDFCBK', sms('300.00', '4${random.nextInt(1 << 31)}'), at: DateTime.now());
    source.enqueue('AD-HDFCBK', '123456 is your OTP for txn of Rs.300.00 at HDFC Bank. Do not share.');
    final report = await pipeline.processQueue();
    expect(report.payments, 1);
    expect(report.unparsed, 1);

    var outcome = await sync.run();
    expect(outcome.clean, isTrue);
    expect(outcome.failed, 0);
    expect(outcome.synced.single.ask, 'payee');
    var first = (await store.watchAll().first).single;
    expect(first.syncState, 'synced');
    expect(first.kind, 'unknown');
    expect(first.amountExact, 300);

    // What the server holds: a band, never the amount or the message.
    final onServer = await transactions.get(first.serverId!);
    expect(onServer.amountBand, '200_500');
    expect(onServer.payee.name, payee);
    expect(onServer.hasLocation, isFalse, reason: 'ingested in the background, without a location');

    // Uploading again is answered with "duplicate", not a second transaction.
    final again = await transactions.ingest([
      IngestRow(
        clientTxnId: first.clientTxnId,
        payeeName: first.payeeName,
        occurredOn: first.occurredOn,
        dayPart: first.dayPart,
        amountBand: first.amountBand,
        ref: first.ref,
      ),
    ]);
    expect(again.single.status, 'duplicate');
    expect(again.single.transaction.id, first.serverId);

    // A row with a forbidden field is rejected per row, in the shape the outbox expects.
    try {
      await client.dio.post<dynamic>('transactions/batch/', data: {
        'transactions': [
          {
            'client_txn_id': '00000000-0000-5000-8000-0000000000aa',
            'payee_name': 'X',
            'occurred_on': first.occurredOn,
            'amount_band': 'lt_50',
            'source': 'sms',
            'amount': 300,
          },
        ],
      });
      fail('the server accepted an exact amount');
    } catch (e) {
      final error = ApiException.from(e);
      expect(error.statusCode, 400);
      final perRow = (error.body as Map)['transactions'];
      expect(perRow is Map ? perRow['0'] : (perRow as List).single, contains('amount'));
    }

    // --- confirm the shop (within 10 minutes, so with a location) ------------------
    expect(await payees.suggestions(first), isEmpty);
    final categories = await payees.categories();
    expect(categories.map((c) => c.slug), contains('tea-stall'));
    final here = await payees.hereFor(first);
    expect(here, isNotNull);
    final shopName = 'Live Test Tea ${random.nextInt(1 << 30)}';
    await payees.addMerchant(first, NewMerchant(name: shopName, category: 'tea-stall'), here: here);

    first = (await store.get(first.clientTxnId))!;
    expect(first.kind, 'merchant');
    expect(first.merchantInfo!.name, shopName);
    expect(first.taggedItems, isNotEmpty, reason: 'the server guesses the category default item');
    expect(first.taggedItems.every((t) => t.inferred), isTrue);
    expect(first.state, TxnState.needsItems);
    expect((await transactions.get(first.serverId!)).hasLocation, isTrue,
        reason: 'the location endpoint attached the rounded location');
    expect((await merchants.search(shopName.substring(0, 12))).map((m) => m.name), contains(shopName));

    // --- next payment to the same payee resolves by itself -------------------------
    source.enqueue('VM-HDFCBK-S', sms('55.00', '5${random.nextInt(1 << 31)}'),
        at: DateTime.now().add(const Duration(seconds: 1)));
    await pipeline.processQueue();
    outcome = await sync.run();
    expect(outcome.synced.single.ask, 'items');
    final second = (await store.get(outcome.synced.single.clientTxnId))!;
    expect(second.kind, 'merchant');
    expect(second.merchantInfo!.name, shopName);
    final guessName = second.taggedItems.single.item.name;

    // --- tag: "Yes, correct" ----------------------------------------------------------
    await items.confirm(second);
    expect((await store.get(second.clientTxnId))!.state, TxnState.done);

    // --- correct a tag: other item, quantity 2, plus free text ------------------------------
    final chips = await items.chips(first);
    expect(chips, isNotEmpty);
    final other = chips.firstWhere((c) => c.name != guessName, orElse: () => chips.first);
    await items.save(first, [ItemEntry.catalogue(other.id, 2), const ItemEntry.named('live test biscuit', 1)]);
    final corrected = (await store.get(first.clientTxnId))!;
    expect(corrected.taggedItems.every((t) => !t.inferred), isTrue);
    expect(corrected.taggedItems.firstWhere((t) => t.item.id == other.id).quantity, 2);
    expect(corrected.taggedItems, hasLength(2));
    expect(corrected.state, TxnState.done);

    // --- correct the payee: shop → person → shop ------------------------------------------
    await payees.markPerson(first);
    expect((await store.get(second.clientTxnId))!.kind, 'person');
    expect((await transactions.get(first.serverId!)).items, isEmpty);
    final found = await merchants.search(shopName.substring(0, 12));
    await payees.chooseMerchant((await store.get(first.clientTxnId))!, found.firstWhere((m) => m.name == shopName));
    expect((await store.get(first.clientTxnId))!.kind, 'merchant');

    // --- reconcile restores everything on a fresh install, without amounts -------------------
    final fresh = memoryStore();
    addTearDown(fresh.db.close);
    final restore = SyncService(store: fresh, transactions: transactions, merchants: merchants, tagging: tagging);
    expect((await restore.reconcile()).clean, isTrue);
    final restored = await fresh.watchAll().first;
    expect(restored, hasLength(2));
    expect(restored.every((r) => r.amountExact == null && r.kind == 'merchant'), isTrue);

    // --- withdraw location: stored locations are erased ---------------------------------------
    await consents.set(Purpose.location, granted: false, noticeVersion: noticeVersion);
    expect((await transactions.get(first.serverId!)).hasLocation, isFalse);
    await expectLater(
      transactions.setLocation(first.serverId!, const LatLng(28.628, 77.365)),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'location_consent_required')
          .having((e) => e.isConsentRequired, 'treated as the payment consent', isFalse)),
    );

    // --- export ----------------------------------------------------------------------------
    final export = await account.export();
    expect((export['user'] as Map)['phone'], phone);
    final exported = export['transactions'] as List;
    expect(exported, hasLength(2));
    expect(exported.every((t) => (t as Map)['amount_band'] != null && !t.containsKey('amount')), isTrue);

    // --- delete account ----------------------------------------------------------------------
    await account.deleteAccount();
    deleted = true;
    // The access token is dead, the refresh is refused with 401, and the client
    // drops its tokens: the app is signed out.
    await expectLater(account.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(await tokens.load(), isNull);
  }, skip: base == null ? 'Set LIVE_API_BASE_URL to run against a real backend.' : false, timeout: const Timeout(Duration(minutes: 2)));
}
