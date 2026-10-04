import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/widgets/payment_row.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/features/home/payment_list.dart';

import '../support/fakes.dart';

LocalTransaction txn(
  String id, {
  String kind = 'unknown',
  double? amount = 100,
  List<Map<String, dynamic>> items = const [],
  String? ask,
  DateTime? at,
  String syncState = 'synced',
}) =>
    LocalTransaction(
      clientTxnId: id,
      bank: 'HDFC',
      payeeName: 'P',
      amountExact: amount,
      occurredOn: '2026-10-07',
      receivedAt: at ?? DateTime(2026, 10, 7, 12),
      ref: '',
      source: 'sms',
      syncState: syncState,
      serverId: 's',
      kind: kind,
      merchant: kind == 'merchant' ? jsonEncode(teaStall) : null,
      items: jsonEncode(items),
      ask: ask,
      notified: false,
      payeeId: 1,
      amountBand: '50_200',
      dayPart: 'afternoon',
      fromHistory: false,
    );

void main() {
  final now = DateTime(2026, 10, 7, 19); // a Wednesday

  test('row states: only the user’s own answer is "done"', () {
    expect(rowStateOf(txn('a')), PaymentRowState.needsShop);
    expect(rowStateOf(txn('a', kind: 'person')), PaymentRowState.person);
    expect(rowStateOf(txn('a', kind: 'merchant')), PaymentRowState.needsItems);
    expect(rowStateOf(txn('a', kind: 'merchant', items: [guess('Tea')])), PaymentRowState.guessed);
    expect(
      rowStateOf(txn('a', kind: 'merchant', items: [guess('Tea', inferred: false), guess('Bun', id: 9)])),
      PaymentRowState.guessed,
      reason: 'one guess among the tags keeps the row out of green',
    );
    expect(rowStateOf(txn('a', kind: 'merchant', items: [guess('Tea', inferred: false)])), PaymentRowState.done);
  });

  test('items text and amount text', () {
    final row = txn('a', kind: 'merchant', items: [guess('Tea', quantity: 2), guess('Samosa', id: 4)]);
    expect(itemsText(row), 'Tea × 2 · Samosa');
    expect(amountText(txn('a', amount: 1200)), '₹1,200');
    expect(amountText(txn('a', amount: null)), '₹50 to 200');
  });

  test('filters', () {
    final rows = [
      txn('unknown'),
      txn('guess', kind: 'merchant', items: [guess('Tea')], ask: 'items'),
      txn('learned', kind: 'merchant', items: [guess('Tea')]),
      txn('done', kind: 'merchant', items: [guess('Tea', inferred: false)]),
      txn('person', kind: 'person'),
    ];
    List<String> ids(PaymentFilter f) => [for (final r in rows) if (matchesFilter(r, f)) r.clientTxnId];
    expect(ids(PaymentFilter.all), hasLength(5));
    expect(ids(PaymentFilter.needsYou), ['unknown', 'guess'], reason: 'the server stopped asking about "learned"');
    expect(ids(PaymentFilter.shops), ['guess', 'learned', 'done']);
    expect(ids(PaymentFilter.people), ['person']);
  });

  test('grouping by day keeps order and names the days', () {
    final rows = [
      txn('a', at: DateTime(2026, 10, 7, 18)),
      txn('b', at: DateTime(2026, 10, 7, 9)),
      txn('c', at: DateTime(2026, 10, 6, 23, 59)),
      txn('d', at: DateTime(2026, 10, 3, 12)),
    ];
    final groups = groupByDay(rows, now: now);
    expect([for (final g in groups) g.label], ['Today', 'Yesterday', 'Sat, 3 Oct']);
    expect([for (final g in groups) g.rows.length], [2, 1, 1]);
    expect(groupByDay(const [], now: now), isEmpty);
  });

  test('the week runs from Monday and sums only exact amounts on this phone', () {
    final rows = [
      txn('wed', amount: 300, at: DateTime(2026, 10, 7, 12)),
      txn('mon', amount: 55.5, at: DateTime(2026, 10, 5, 0, 1)),
      txn('restored', amount: null, at: DateTime(2026, 10, 6, 12)),
      txn('last-sunday', amount: 999, at: DateTime(2026, 10, 4, 23, 59)),
    ];
    final summary = weekSummary(rows, now: now);
    expect(summary.total, 355.5);
    expect(summary.count, 3);
    expect(summary.needsYou, 4, reason: 'every unanswered payment counts, whatever its date');
  });

  test('upload marks', () {
    expect(syncMark(txn('a')), isNull);
    expect(syncMark(txn('a', syncState: 'pending'))!.label, 'Waiting to upload');
    expect(syncMark(txn('a', syncState: 'failed'))!.label, 'Not uploaded');
  });
}
