import 'dart:convert';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';

/// Shows prompts to the user. The real one posts Android notifications.
abstract class PromptNotifier {
  /// "Paid ₹300 to RAMESH KUMAR. Shop or person?" with [Shop] and [Person].
  Future<void> showPayeePrompt({required String clientTxnId, required String title, required String body});

  /// "Paid ₹55 at Sharma Tea Stall. For Tea?" with [Yes] (when there is a guess),
  /// [Something else] and [Not a shop].
  Future<void> showItemsPrompt({
    required String clientTxnId,
    required String title,
    required String body,
    required bool hasGuess,
  });

  /// One notification at [at]: "5 payments to tag". Replaces any earlier summary.
  Future<void> scheduleSummary({required int count, required DateTime at});

  Future<void> cancel(String clientTxnId);

  Future<void> cancelAll();
}

class SilentNotifier implements PromptNotifier {
  const SilentNotifier();

  @override
  Future<void> showPayeePrompt({required String clientTxnId, required String title, required String body}) async {}

  @override
  Future<void> showItemsPrompt({
    required String clientTxnId,
    required String title,
    required String body,
    required bool hasGuess,
  }) async {}

  @override
  Future<void> scheduleSummary({required int count, required DateTime at}) async {}

  @override
  Future<void> cancel(String clientTxnId) async {}

  @override
  Future<void> cancelAll() async {}
}

/// The OS permission to post notifications (asked on Android 13 and later).
abstract class NotificationPermissions {
  /// Shows the system prompt. True when notifications are allowed.
  Future<bool> request();

  Future<bool> enabled();
}

class NoNotificationPermissions implements NotificationPermissions {
  const NoNotificationPermissions();

  @override
  Future<bool> request() async => false;

  @override
  Future<bool> enabled() async => false;
}

class PromptText {
  const PromptText(this.title, this.body, {this.hasGuess = false});
  final String title;
  final String body;
  final bool hasGuess;
}

String _amount(LocalTransaction row) =>
    row.amountExact != null ? formatRupees(row.amountExact!) : bandLabel(row.amountBand);

/// Wording of the payee prompt. The amount is the exact one: it is shown on this
/// device only and never sent anywhere.
PromptText payeePromptText(LocalTransaction row) =>
    PromptText('Paid ${_amount(row)} to ${row.payeeDisplay}', 'New here. Shop or person?');

PromptText itemsPromptText(LocalTransaction row) {
  final guesses = [
    for (final tag in row.taggedItems) tag.quantity > 1 ? '${tag.quantity} × ${tag.item.name}' : tag.item.name,
  ];
  final title = 'Paid ${_amount(row)} at ${row.title}';
  if (guesses.isEmpty) return PromptText(title, 'What did you get?');
  return PromptText(title, 'For ${guesses.join(', ')}?', hasGuess: true);
}

String summaryText(int count) => count == 1 ? '1 payment to tag' : '$count payments to tag';

/// Second line of the evening summary.
const summaryBody = 'Evening round-up. Takes under a minute.';

enum PromptDecision { none, notify, summary }

/// Decides which freshly synced payments deserve a notification, and keeps prompts
/// from becoming a nuisance.
///
///  - no notification for history-import rows or when the server asks nothing,
///  - none for a payment older than 30 minutes when it syncs,
///  - at most 6 prompts a day; the rest are collected into one summary at 8 pm.
class PromptService {
  PromptService({required this._store, required this._notifier, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final LocalStore _store;
  final PromptNotifier _notifier;
  final DateTime Function() _now;

  static const dailyCap = 6;
  static const maxAge = Duration(minutes: 30);
  static const summaryHour = 20;

  Future<void> afterSync(List<AppliedResult> results) async {
    for (final result in results) {
      final row = await _store.get(result.clientTxnId);
      if (row == null) continue;
      switch (await _decide(row)) {
        case PromptDecision.none:
          break;
        case PromptDecision.notify:
          await _show(row);
        case PromptDecision.summary:
          await _defer(row);
      }
    }
  }

  Future<PromptDecision> _decide(LocalTransaction row) async {
    if (row.ask != 'payee' && row.ask != 'items') return PromptDecision.none;
    if (row.fromHistory || row.notified) return PromptDecision.none;
    final age = _now().difference(row.receivedAt);
    if (age > maxAge) return PromptDecision.none;
    // Exactly one isolate wins this, so a payment is never announced twice.
    if (!await _store.claimNotification(row.clientTxnId)) return PromptDecision.none;

    final slot = await _store.takePromptSlot(_dayKey(_now()), dailyCap);
    return slot ? PromptDecision.notify : PromptDecision.summary;
  }

  Future<void> _show(LocalTransaction row) async {
    if (row.ask == 'payee') {
      final text = payeePromptText(row);
      await _notifier.showPayeePrompt(clientTxnId: row.clientTxnId, title: text.title, body: text.body);
    } else {
      final text = itemsPromptText(row);
      await _notifier.showItemsPrompt(
        clientTxnId: row.clientTxnId,
        title: text.title,
        body: text.body,
        hasGuess: text.hasGuess,
      );
    }
  }

  /// Over the daily cap: add the payment to the 8 pm summary.
  Future<void> _defer(LocalTransaction row) async {
    final now = _now();
    final storedAt = DateTime.tryParse(await _store.getSetting(SettingKeys.summaryAt) ?? '');
    var ids = <String>[];
    var at = nextSummaryTime(now);
    if (storedAt != null && storedAt.isAfter(now)) {
      // A summary is already waiting: add to it.
      at = storedAt;
      try {
        ids = [for (final id in jsonDecode(await _store.getSetting(SettingKeys.summaryIds) ?? '[]') as List) id as String];
      } catch (_) {
        ids = [];
      }
    }
    if (!ids.contains(row.clientTxnId)) ids.add(row.clientTxnId);

    // Count only payments that still need an answer.
    final open = <String>[];
    for (final id in ids) {
      final candidate = await _store.get(id);
      if (candidate != null && candidate.needsAttention) open.add(id);
    }
    await _store.setSetting(SettingKeys.summaryIds, jsonEncode(open));
    await _store.setSetting(SettingKeys.summaryAt, at.toIso8601String());
    if (open.isNotEmpty) await _notifier.scheduleSummary(count: open.length, at: at);
  }

  /// 8 pm today, or tomorrow when it is already past.
  static DateTime nextSummaryTime(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, summaryHour);
    return now.isBefore(today) ? today : DateTime(now.year, now.month, now.day + 1, summaryHour);
  }

  static String _dayKey(DateTime time) => '${time.year}-${time.month}-${time.day}';
}
