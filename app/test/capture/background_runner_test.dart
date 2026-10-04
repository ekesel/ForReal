import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/providers.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  late Harness h;
  // The fake payments are stamped 2 Aug 2026; make them "just now" for the prompt rules.
  setUp(() async {
    h = Harness();
    h.serveTemplates();
    await h.store.saveTemplates(5, [hdfcTemplate]);
    await grantConsents(h.store);
  });
  tearDown(() => h.dispose());

  void acceptAll() {
    h.api.on('POST', 'transactions/batch/', (r) {
      return FakeResponse.ok({
        'results': [
          for (final row in r.json['transactions'] as List)
            ingestResult(serverTxn((row as Map)['client_txn_id'] as String)),
        ],
      });
    });
  }

  test('a queued bank message becomes a server transaction and a notification', () async {
    h.source.enqueue('AD-HDFCBK', hdfcSms(), at: DateTime.now().subtract(const Duration(seconds: 20)));
    acceptAll();

    final retry = await h.container.read(backgroundRunnerProvider).run(reason: 'sms');

    expect(retry, isFalse);
    expect(h.source.queue, isEmpty);
    final sent = (h.api.to('POST', 'transactions/batch/').single.json['transactions'] as List).single as Map;
    expect(sent['payee_name'], 'RAMESH  KUMAR');
    expect(sent['amount_band'], '200_500');
    expect(sent.containsKey('amount'), isFalse);
    expect(h.notifier.shown.single, contains('Paid ₹300 to RAMESH KUMAR|New here. Shop or person?'));
    expect(h.api.to('GET', 'parser-templates/'), isEmpty, reason: 'templates are cached; no download per message');
  });

  test('offline: the payment is kept and another run is requested', () async {
    h.source.enqueue('AD-HDFCBK', hdfcSms(), at: DateTime.now());
    h.api.on('POST', 'transactions/batch/', (_) => throw const Offline());

    final retry = await h.container.read(backgroundRunnerProvider).run(reason: 'sms');

    expect(retry, isTrue);
    expect(h.source.queue, isEmpty, reason: 'parsed and stored locally, so the raw message can go');
    expect(await h.store.pendingCount(), 1);
    expect(h.notifier.shown, isEmpty, reason: 'the notification follows the sync');
  });

  test('the periodic run refreshes templates', () async {
    acceptAll();
    await h.container.read(backgroundRunnerProvider).run(reason: 'periodic');
    expect(h.api.to('GET', 'parser-templates/'), hasLength(1));
    expect(h.source.allowedSenders, {'HDFCBK'});
  });

  test('signed out: nothing is read, parsed or sent', () async {
    h.dispose();
    h = Harness(signedIn: false);
    h.source.enqueue('AD-HDFCBK', hdfcSms());

    final retry = await h.container.read(backgroundRunnerProvider).run(reason: 'sms');

    expect(retry, isFalse);
    expect(h.api.requests, isEmpty);
    expect(h.source.queue, hasLength(1));
  });
}
