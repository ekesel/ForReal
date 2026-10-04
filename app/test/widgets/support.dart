import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/raw_message.dart';
import 'package:forreal/capture/transaction_source.dart';
import 'package:forreal/core/providers.dart';
import 'package:forreal/core/theme/app_theme.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/features/ui_providers.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// A Wednesday evening, so "this week" has a Monday and a Tuesday behind it.
final fixedNow = DateTime(2026, 10, 7, 19, 0);

LocalTransaction row(
  String id, {
  String kind = 'unknown',
  double? amount = 300,
  String payee = 'RAMESH  KUMAR',
  Map<String, dynamic>? merchant,
  List<Map<String, dynamic>> items = const [],
  String? ask = 'payee',
  String syncState = 'synced',
  String? error,
  int? payeeId = 7,
  DateTime? at,
}) =>
    LocalTransaction(
      clientTxnId: id,
      bank: 'HDFC',
      payeeName: payee,
      amountExact: amount,
      occurredOn: '2026-10-07',
      receivedAt: at ?? DateTime(2026, 10, 7, 18, 42),
      ref: '',
      source: 'sms',
      syncState: syncState,
      serverId: syncState == 'synced' ? 's-$id' : null,
      kind: kind,
      merchant: merchant == null ? null : jsonEncode(merchant),
      items: jsonEncode(items),
      ask: ask,
      notified: false,
      payeeId: payeeId,
      amountBand: '200_500',
      dayPart: 'evening',
      fromHistory: false,
      error: error,
    );

const bakery = {'id': 'm-2', 'name': 'Modern Bakery', 'category': 'bakery', 'is_online': false, 'location': null};
const rapido = {'id': 'm-3', 'name': 'Rapido', 'category': 'transport', 'is_online': true, 'location': null};

/// The payments of the home design: one of each state, over two days.
List<LocalTransaction> designRows() => [
      row('unknown', at: DateTime(2026, 10, 7, 18, 42)),
      row('needs-items', kind: 'merchant', merchant: teaStall, ask: 'items', amount: 55, at: DateTime(2026, 10, 7, 16, 10), payeeId: 8),
      row('done', kind: 'merchant', merchant: bakery, ask: null, amount: 420, payeeId: 9, at: DateTime(2026, 10, 7, 13, 30),
          items: [guess('Cake', inferred: false, id: 5), guess('Bread', inferred: false, id: 6)]),
      row('guessed', kind: 'merchant', merchant: rapido, ask: 'items', amount: 86, payeeId: 10, at: DateTime(2026, 10, 6, 21, 5),
          items: [guess('Ride', id: 7)]),
      row('person', kind: 'person', ask: null, amount: 1200, payee: 'Rina Devi', payeeId: 11, at: DateTime(2026, 10, 6, 19, 40)),
    ];

/// Sets the test surface. Sizes are logical pixels.
void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A screen inside the app's theme, backed by the harness (fake API, source and store).
Widget screen(
  Harness h,
  Widget child, {
  List<LocalTransaction> rows = const [],
  SmsPermission sms = SmsPermission.granted,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  h.source.permission = sms;
  final container = ProviderContainer(
    parent: h.container,
    retry: (_, _) => null,
    overrides: [
      clockProvider.overrideWithValue(() => fixedNow),
      transactionsProvider.overrideWith((ref) => Stream.value(rows)),
      transactionProvider.overrideWith(
        (ref, id) => Stream.value(rows.where((r) => r.clientTxnId == id).firstOrNull),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(brightness),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: child,
    ),
  );
}

/// A bare widget inside the theme, for the shared widgets.
Widget themed(Widget child, {Brightness brightness = Brightness.light, double textScale = 1}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(brightness),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(20), child: child))),
    );

final sampleUnparsed = RawMessage(
  sender: 'AD-HDFCBK',
  receivedAt: DateTime(2026, 10, 7, 9, 5),
  body: 'UPDATE: INR 1,250.00 debited from HDFC Bank XX1234 on 07-OCT-26. Info: UPI/400012345678. Avl bal: INR 9,876.50',
);
