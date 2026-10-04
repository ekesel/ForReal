import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/capture_pipeline.dart';
import 'package:forreal/capture/raw_message.dart';
import 'package:forreal/capture/template_sync.dart';
import 'package:forreal/data/api/repositories.dart';
import 'package:forreal/data/local_store.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';

void main() {
  late TestBackend backend;
  late LocalStore store;
  late FakeSource source;
  late TemplateSync templates;
  late CapturePipeline pipeline;

  setUp(() async {
    backend = TestBackend();
    store = memoryStore();
    source = FakeSource();
    templates = TemplateSync(api: TemplatesApi(backend.client), store: store, control: source);
    pipeline = CapturePipeline(source: source, store: store, templates: templates);
    await store.saveTemplates(1, [hdfcTemplate]);
    await grantConsents(store);
  });
  tearDown(() => store.db.close());

  group('template sync', () {
    test('downloads, caches and pushes sender codes to the native filter', () async {
      await store.saveTemplates(0, []);
      await store.removeSetting(SettingKeys.templatesVersion);
      backend.api.reply('GET', 'parser-templates/', {'version': 9, 'changed': true, 'templates': [hdfcTemplate]});

      final parser = await templates.sync();

      expect(parser.senderCodes, {'HDFCBK'});
      expect(source.allowedSenders, {'HDFCBK'});
      expect(await store.templatesVersion(), 9);
      expect(backend.api.requests.single.query, isEmpty);
    });

    test('sends the known version and keeps the cache when unchanged', () async {
      backend.api.reply('GET', 'parser-templates/', {'version': 1, 'changed': false});
      await templates.sync();
      expect(backend.api.requests.single.query, {'version': '1'});
      expect(await store.loadTemplates(), hasLength(1));
      expect(source.allowedSenders, {'HDFCBK'});
    });

    test('works from the cache when offline', () async {
      backend.api.on('GET', 'parser-templates/', (_) => throw const Offline());
      final parser = await templates.sync();
      expect(parser.senderCodes, {'HDFCBK'});
      expect(source.allowedSenders, {'HDFCBK'});
    });

    test('deactivated templates remove the sender from the filter', () async {
      backend.api.reply('GET', 'parser-templates/', {'version': 2, 'changed': true, 'templates': []});
      await templates.sync();
      expect(source.allowedSenders, isEmpty);
    });
  });

  group('queue', () {
    test('a bank payment becomes a pending local row and is acknowledged', () async {
      source.enqueue('AD-HDFCBK', hdfcSms());

      final report = await pipeline.processQueue();

      expect(report.payments, 1);
      expect(source.queue, isEmpty);
      expect(source.acknowledged, [1]);
      final row = (await store.pending()).single;
      expect(row.payeeName, 'RAMESH  KUMAR');
      expect(row.amountExact, 300);
      expect(row.ref, '400012345678');
      expect(row.bank, 'HDFC');
      expect(row.fromHistory, isFalse);
    });

    test('the message text is not kept after a successful parse', () async {
      source.enqueue('AD-HDFCBK', hdfcSms());
      await pipeline.processQueue();
      expect(await store.unparsedCount(), 0);
      final dump = (await store.db.customSelect('SELECT * FROM local_transactions').get()).map((r) => r.data).toString();
      expect(dump, isNot(contains('Not You?')));
      expect(dump, isNot(contains('*1234')));
      expect(dump, isNot(contains('18002586161')));
    });

    test('OTPs are kept as unparsed, credits are ignored, both are acknowledged', () async {
      await store.saveTemplates(1, [
        hdfcTemplate,
        {
          'id': 2,
          'bank': 'HDFC',
          'sender_ids': ['HDFCBK'],
          'txn_type': 'credit',
          'pattern': r'Rs\.(?<amount>[\d,.]+) credited to .* from (?<payee>.+)',
          'priority': 20,
        },
      ]);
      source.enqueue('AD-HDFCBK', '123456 is your OTP for txn of Rs.300.00 at HDFC Bank. Do not share.');
      source.enqueue('AD-HDFCBK', 'Rs.500.00 credited to HDFC Bank A/C *1234 from VPA x@okaxis');

      final report = await pipeline.processQueue();

      expect(report.unparsed, 1);
      expect(report.credits, 1);
      expect(report.payments, 0);
      expect(await store.pending(), isEmpty);
      expect((await store.watchUnparsed().first).single.body, contains('OTP'));
      expect(source.queue, isEmpty);
    });

    test('the same message twice is one payment', () async {
      source.enqueue('AD-HDFCBK', hdfcSms());
      await pipeline.processQueue();
      source.enqueue('AD-HDFCBK', hdfcSms());
      final report = await pipeline.processQueue();
      expect(report.duplicates, 1);
      expect(await store.pending(), hasLength(1));
    });

    test('more than one page of the queue is drained', () async {
      for (var i = 0; i < 120; i++) {
        source.enqueue('AD-HDFCBK', hdfcSms(ref: '4000$i'), at: DateTime(2026, 8, 2, 10).add(Duration(seconds: i)));
      }
      final report = await pipeline.processQueue();
      expect(report.payments, 120);
      expect(source.queue, isEmpty);
    });

    test('without the private-analytics consent nothing is stored', () async {
      await grantConsents(store, privateAnalytics: false);
      source.enqueue('AD-HDFCBK', hdfcSms());
      source.enqueue('AD-HDFCBK', 'some new format');

      final report = await pipeline.processQueue();

      expect(report.dropped, 2);
      expect(await store.pending(), isEmpty);
      expect(await store.unparsedCount(), 0);
      expect(source.queue, isEmpty, reason: 'dropped messages do not linger in the queue');
    });

    test('a message from a non-bank sender is never stored, even if it reaches Dart', () async {
      final report = await pipeline.process([
        RawMessage(sender: '+919876543210', receivedAt: DateTime(2026, 8, 2), body: hdfcSms()),
      ]);
      expect(report.dropped, 1);
      expect(await store.pending(), isEmpty);
      expect(await store.unparsedCount(), 0);
    });
  });

  group('history import', () {
    test('imports every page as history rows, idempotently', () async {
      for (var i = 0; i < 5; i++) {
        source.inbox.add(RawMessage(
          sender: 'VM-HDFCBK-S',
          receivedAt: DateTime(2026, 7, 10 + i, 9),
          body: hdfcSms(ref: '5000$i'),
        ));
      }
      source.inbox.add(RawMessage(sender: 'VM-HDFCBK-S', receivedAt: DateTime(2026, 5, 1), body: hdfcSms(ref: '1')));

      final first = await pipeline.importHistory(DateTime(2026, 7, 1));
      final again = await pipeline.importHistory(DateTime(2026, 7, 1));

      expect(first.payments, 5);
      expect(again.payments, 0);
      expect(again.duplicates, 5);
      final rows = await store.pending();
      expect(rows, hasLength(5));
      expect(rows.every((r) => r.fromHistory), isTrue);
    });

    test('a message captured live and then imported is the same payment', () async {
      final at = DateTime(2026, 8, 2, 18, 30);
      source.enqueue('AD-HDFCBK', hdfcSms(), at: at);
      await pipeline.processQueue();
      source.inbox.add(RawMessage(sender: 'AD-HDFCBK', receivedAt: at, body: hdfcSms()));
      await pipeline.importHistory(DateTime(2026, 8, 1));
      final rows = await store.pending();
      expect(rows, hasLength(1));
      expect(rows.single.fromHistory, isFalse);
    });
  });
}
