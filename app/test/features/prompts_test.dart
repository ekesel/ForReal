import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/format.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/notifications/prompts.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/fakes.dart';

void main() {
  late LocalStore store;
  late RecordingNotifier notifier;
  late DateTime now;
  late PromptService prompts;

  /// Stores a payment and the server's answer for it, as a sync would.
  Future<AppliedResult> synced(
    String id, {
    String? ask = 'payee',
    Duration age = const Duration(minutes: 1),
    bool fromHistory = false,
    double amount = 300,
    String kind = 'unknown',
    List<Map<String, dynamic>> items = const [],
  }) async {
    await store.insertParsed(parsed(id, at: now.subtract(age), amount: amount), fromHistory: fromHistory);
    return store.applyIngestResult(
      id,
      IngestResult.fromJson(ingestResult(
        serverTxn(id, kind: kind, merchant: kind == 'merchant' ? teaStall : null, items: items),
        ask: ask,
      )),
    );
  }

  setUp(() {
    store = memoryStore();
    notifier = RecordingNotifier();
    now = DateTime(2026, 8, 2, 13, 0);
    prompts = PromptService(store: store, notifier: notifier, now: () => now);
  });
  tearDown(() => store.db.close());

  test('an unknown payee asks "Shop or person?" with the exact local amount', () async {
    await prompts.afterSync([await synced('a')]);
    expect(notifier.shown.single, 'payee|a|Paid ₹300 to RAMESH KUMAR|New here. Shop or person?');
    expect((await store.get('a'))!.notified, isTrue);
  });

  test('a known shop asks about the guessed items', () async {
    await prompts.afterSync([
      await synced('a', ask: 'items', kind: 'merchant', amount: 55, items: [guess('Tea')]),
    ]);
    expect(notifier.shown.single, 'items|a|Paid ₹55 at Sharma Tea Stall|For Tea?|true');
  });

  test('several guesses and quantities are listed', () async {
    await prompts.afterSync([
      await synced('a', ask: 'items', kind: 'merchant', items: [guess('Tea', quantity: 2), guess('Samosa', id: 4)]),
    ]);
    expect(notifier.shown.single, contains('For 2 × Tea, Samosa?'));
  });

  test('a shop with no guess asks an open question and offers no "Yes"', () async {
    await prompts.afterSync([await synced('a', ask: 'items', kind: 'merchant', amount: 55.5)]);
    expect(notifier.shown.single, 'items|a|Paid ₹55.50 at Sharma Tea Stall|What did you get?|false');
  });

  test('nothing to ask means no notification', () async {
    await prompts.afterSync([await synced('a', ask: null, kind: 'person')]);
    expect(notifier.shown, isEmpty);
    expect((await store.get('a'))!.notified, isFalse);
  });

  test('history-import rows never notify', () async {
    await prompts.afterSync([await synced('a', fromHistory: true)]);
    expect(notifier.shown, isEmpty);
    expect(notifier.summaries, isEmpty);
  });

  test('a payment older than 30 minutes at sync does not notify', () async {
    await prompts.afterSync([
      await synced('old', age: const Duration(minutes: 31)),
      await synced('fresh', age: const Duration(minutes: 29)),
    ]);
    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.single, startsWith('payee|fresh|'));
  });

  test('a payment is announced once even if it syncs twice', () async {
    final result = await synced('a');
    await prompts.afterSync([result]);
    await prompts.afterSync([result]);
    expect(notifier.shown, hasLength(1));
  });

  test('at most 6 prompts a day; the rest go into one 8 pm summary', () async {
    final results = [for (var i = 0; i < 9; i++) await synced('t$i')];
    await prompts.afterSync(results);

    expect(notifier.shown, hasLength(6));
    expect(notifier.summaries, hasLength(3), reason: 'rescheduled with a growing count');
    expect(notifier.summaries.last.count, 3);
    expect(notifier.summaries.last.at, DateTime(2026, 8, 2, 20));
    expect(summaryText(3), '3 payments to tag');
    expect(summaryText(1), '1 payment to tag');
    expect(summaryBody, 'Evening round-up. Takes under a minute.');
  });

  test('the cap resets the next day', () async {
    await prompts.afterSync([for (var i = 0; i < 6; i++) await synced('t$i')]);
    now = DateTime(2026, 8, 3, 9);
    await prompts.afterSync([await synced('next')]);
    expect(notifier.shown, hasLength(7));
    expect(notifier.summaries, isEmpty);
  });

  test('after 8 pm the summary moves to the next evening', () async {
    now = DateTime(2026, 8, 2, 21);
    await prompts.afterSync([for (var i = 0; i < 7; i++) await synced('t$i')]);
    expect(notifier.summaries.single.at, DateTime(2026, 8, 3, 20));
  });

  test('the summary counts only payments that still need an answer', () async {
    await prompts.afterSync([for (var i = 0; i < 7; i++) await synced('t$i')]);
    expect(notifier.summaries.last.count, 1);
    // The deferred one gets answered in the app before the next overflow.
    await store.applyPayeeResolution(7, kind: 'person');
    await store.insertParsed(parsed('later', at: now), fromHistory: false);
    final later = await store.applyIngestResult(
        'later', IngestResult.fromJson(ingestResult(serverTxn('later', payee: 8))));
    await prompts.afterSync([later]);
    expect(notifier.summaries.last.count, 1);
  });

  test('a summary that already fired starts a new list', () async {
    await prompts.afterSync([for (var i = 0; i < 8; i++) await synced('t$i')]);
    expect(notifier.summaries.last.count, 2);
    now = DateTime(2026, 8, 3, 9);
    await prompts.afterSync([for (var i = 0; i < 7; i++) await synced('n$i')]);
    expect(notifier.summaries.last.count, 1);
    expect(notifier.summaries.last.at, DateTime(2026, 8, 3, 20));
  });

  test('the last slot of the day can be taken only once', () async {
    final taken = await Future.wait([for (var i = 0; i < 10; i++) store.takePromptSlot('2026-8-2', 6)]);
    expect(taken.where((t) => t), hasLength(6));
    expect(await store.takePromptSlot('2026-8-3', 6), isTrue, reason: 'a new day starts from zero');
    expect(await store.getSetting('prompt_count:2026-8-2'), isNull, reason: 'old counters are cleaned up');
  });

  test('a summary time is an absolute instant and needs no time zone database', () {
    final at = DateTime(2026, 8, 2, 20);
    final scheduled = tz.TZDateTime.from(at, tz.UTC);
    expect(scheduled.millisecondsSinceEpoch, at.millisecondsSinceEpoch);
    // Android resolves this name with ZoneId.of; both spellings are valid there.
    expect(scheduled.location.name, anyOf('UTC', 'Etc/UTC'));
    expect(scheduled.timeZoneOffset, Duration.zero);
  });

  test('next summary time', () {
    expect(PromptService.nextSummaryTime(DateTime(2026, 8, 2, 19, 59)), DateTime(2026, 8, 2, 20));
    expect(PromptService.nextSummaryTime(DateTime(2026, 8, 2, 20)), DateTime(2026, 8, 3, 20));
    expect(PromptService.nextSummaryTime(DateTime(2026, 8, 31, 23)), DateTime(2026, 9, 1, 20));
  });

  test('formatting helpers', () {
    expect(formatRupees(300), '₹300');
    expect(formatRupees(55.5), '₹55.50');
    expect(formatRupees(100000), '₹1,00,000');
    expect(bandLabel('200_500'), '₹200 to 500');
    expect(formatDay('2026-08-02', today: DateTime(2026, 9, 1)), '2 Aug');
    expect(formatDay('2025-08-02', today: DateTime(2026, 9, 1)), '2 Aug 2025');
    expect(notificationId('abc'), notificationId('abc'));
    expect(notificationId('abc'), isNot(notificationId('abd')));
    expect(notificationId('abc'), greaterThan(1));
  });
}
