import 'dart:convert';

import 'package:drift/drift.dart';

import '../capture/derived.dart';
import '../capture/parser.dart';
import '../capture/raw_message.dart';
import 'db/database.dart';
import 'models.dart';

/// Where a payment stands for the user.
enum TxnState { needsShop, needsItems, done, person }

extension LocalTransactionView on LocalTransaction {
  Merchant? get merchantInfo => Merchant.decode(merchant);
  List<TaggedItem> get taggedItems => TaggedItem.decodeList(items);

  /// Payee with runs of whitespace collapsed, for the screen.
  String get payeeDisplay => collapseWhitespace(payeeName);

  /// Shop name once confirmed, otherwise the payee as the bank wrote it.
  String get title => merchantInfo?.name ?? payeeDisplay;

  TxnState get state {
    if (kind == 'person') return TxnState.person;
    if (kind != 'merchant') return TxnState.needsShop;
    final tags = taggedItems;
    if (tags.isEmpty) return TxnState.needsItems;
    if (tags.every((t) => !t.inferred)) return TxnState.done;
    // Guesses only. The server stops asking once it has learned the shop's item.
    return ask == 'items' ? TxnState.needsItems : TxnState.done;
  }

  bool get needsAttention => state == TxnState.needsShop || state == TxnState.needsItems;
}

/// What the server said about one uploaded row.
class AppliedResult {
  const AppliedResult({required this.clientTxnId, required this.ask, required this.mergedIntoExisting});
  final String clientTxnId;
  final String? ask;

  /// The server already had this payment under another local row; the extra row was dropped.
  final bool mergedIntoExisting;
}

/// Every read and write of the local database. Screens and services go through this.
class LocalStore {
  LocalStore(this.db);

  final AppDatabase db;

  static const unparsedCap = 200;

  // --- transactions ----------------------------------------------------------

  /// Stores a freshly parsed payment. Returns false when it was already there
  /// (the same message captured or imported before).
  Future<bool> insertParsed(ParsedPayment p, {required bool fromHistory, String source = 'sms'}) async {
    if (await get(p.clientTxnId) != null) return false;
    await db.into(db.localTransactions).insert(
          LocalTransactionsCompanion.insert(
            clientTxnId: p.clientTxnId,
            bank: Value(p.bank),
            payeeName: p.payeeName,
            amountExact: Value(p.amount),
            occurredOn: isoDate(p.occurredOn),
            receivedAt: p.receivedAt,
            ref: Value(p.ref),
            source: Value(source),
            amountBand: amountBand(p.amount),
            dayPart: Value(dayPart(p.receivedAt)),
            fromHistory: Value(fromHistory),
          ),
          // Another isolate may store the same message at the same moment.
          onConflict: DoNothing(),
        );
    return true;
  }

  Future<LocalTransaction?> get(String clientTxnId) =>
      (db.select(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId))).getSingleOrNull();

  Future<LocalTransaction?> byServerId(String serverId) =>
      (db.select(db.localTransactions)..where((t) => t.serverId.equals(serverId))..limit(1)).getSingleOrNull();

  Future<List<LocalTransaction>> byPayee(int payeeId) =>
      (db.select(db.localTransactions)..where((t) => t.payeeId.equals(payeeId))).get();

  Stream<LocalTransaction?> watch(String clientTxnId) =>
      (db.select(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId))).watchSingleOrNull();

  /// Newest first.
  Stream<List<LocalTransaction>> watchAll() => (db.select(db.localTransactions)
        ..orderBy([
          (t) => OrderingTerm.desc(t.receivedAt),
          (t) => OrderingTerm.desc(t.clientTxnId),
        ]))
      .watch();

  /// Rows waiting for upload, oldest first.
  Future<List<LocalTransaction>> pending({int limit = 200}) => (db.select(db.localTransactions)
        ..where((t) => t.syncState.equals('pending'))
        ..orderBy([
          (t) => OrderingTerm.asc(t.receivedAt),
          (t) => OrderingTerm.asc(t.clientTxnId),
        ])
        ..limit(limit))
      .get();

  Future<int> pendingCount() async {
    final count = db.localTransactions.clientTxnId.count();
    final query = db.selectOnly(db.localTransactions)
      ..addColumns([count])
      ..where(db.localTransactions.syncState.equals('pending'));
    return (await query.map((r) => r.read(count)).getSingle()) ?? 0;
  }

  /// Records the server's answer for an uploaded row. `created`, `duplicate` and
  /// `merged` all mean the payment is on the server.
  Future<AppliedResult> applyIngestResult(String clientTxnId, IngestResult result) {
    return db.transaction(() async {
      final txn = result.transaction;
      final other = await byServerId(txn.id);
      if (other != null && other.clientTxnId != clientTxnId) {
        // The server merged this message into a payment another local row already
        // represents (same bank reference). Keep one row.
        await (db.delete(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId))).go();
        await _writeServerFields(other.clientTxnId, txn, ask: Value(result.ask));
        return AppliedResult(clientTxnId: other.clientTxnId, ask: result.ask, mergedIntoExisting: true);
      }
      await _writeServerFields(clientTxnId, txn, ask: Value(result.ask));
      return AppliedResult(clientTxnId: clientTxnId, ask: result.ask, mergedIntoExisting: false);
    });
  }

  Future<void> _writeServerFields(String clientTxnId, ServerTransaction txn, {Value<String?> ask = const Value.absent()}) {
    return (db.update(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId))).write(
      LocalTransactionsCompanion(
        syncState: const Value('synced'),
        serverId: Value(txn.id),
        payeeId: Value(txn.payee.id),
        kind: Value(txn.kind),
        merchant: Value(txn.merchant == null ? null : jsonEncode(txn.merchant!.toJson())),
        items: Value(TaggedItem.encodeList(txn.items)),
        ask: ask,
        error: const Value(null),
      ),
    );
  }

  /// A row the server refused (HTTP 400). It stays visible with the reason and is
  /// not sent again unless the user retries.
  Future<void> markFailed(String clientTxnId, String error) =>
      (db.update(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId)))
          .write(LocalTransactionsCompanion(syncState: const Value('failed'), error: Value(error)));

  Future<void> retryFailed(String clientTxnId) => (db.update(db.localTransactions)
        ..where((t) => t.clientTxnId.equals(clientTxnId) & t.syncState.equals('failed')))
      .write(const LocalTransactionsCompanion(syncState: Value('pending'), error: Value(null)));

  /// Brings a local row in line with the server's copy, or creates one for a payment
  /// this install has never seen (after a reinstall). [ask] is left as it was unless given.
  Future<void> upsertFromServer(ServerTransaction txn, {Value<String?> ask = const Value.absent()}) {
    return db.transaction(() async {
      final local = await get(txn.clientTxnId) ?? await byServerId(txn.id);
      if (local != null) {
        await _writeServerFields(local.clientTxnId, txn, ask: ask);
        return;
      }
      await db.into(db.localTransactions).insert(
            LocalTransactionsCompanion.insert(
              clientTxnId: txn.clientTxnId,
              payeeName: txn.payee.name,
              occurredOn: txn.occurredOn,
              receivedAt: txn.createdAt,
              source: Value(txn.sources.isEmpty ? 'sms' : txn.sources.first),
              syncState: const Value('synced'),
              serverId: Value(txn.id),
              payeeId: Value(txn.payee.id),
              kind: Value(txn.kind),
              merchant: Value(txn.merchant == null ? null : jsonEncode(txn.merchant!.toJson())),
              items: Value(TaggedItem.encodeList(txn.items)),
              ask: ask.present ? ask : Value(defaultAsk(txn.kind, txn.items)),
              amountBand: txn.amountBand,
              dayPart: Value(txn.dayPart),
              // Restored rows must never raise a notification.
              fromHistory: const Value(true),
              notified: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  /// The prompt a payment needs when the server did not say (it only says at ingest).
  static String? defaultAsk(String kind, List<TaggedItem> items) {
    if (kind == 'unknown') return 'payee';
    if (kind == 'merchant' && (items.isEmpty || items.any((i) => i.inferred))) return 'items';
    return null;
  }

  /// The user's answer for a payee applies to every payment to it.
  Future<void> applyPayeeResolution(int payeeId, {required String kind, Merchant? merchant}) {
    final person = kind == 'person';
    return (db.update(db.localTransactions)..where((t) => t.payeeId.equals(payeeId))).write(
      LocalTransactionsCompanion(
        kind: Value(kind),
        merchant: Value(merchant == null ? null : jsonEncode(merchant.toJson())),
        // Payments to a person carry no tags.
        items: person ? const Value('[]') : const Value.absent(),
        ask: Value(person ? null : 'items'),
      ),
    );
  }

  Future<void> setItems(String clientTxnId, List<TaggedItem> items) =>
      (db.update(db.localTransactions)..where((t) => t.clientTxnId.equals(clientTxnId))).write(
        LocalTransactionsCompanion(
          items: Value(TaggedItem.encodeList(items)),
          ask: Value(items.isNotEmpty && items.every((i) => !i.inferred) ? null : 'items'),
        ),
      );

  /// Marks a payment as notified. True for exactly one caller, even when several
  /// isolates sync at once, so a payment never notifies twice.
  Future<bool> claimNotification(String clientTxnId) async {
    final changed = await (db.update(db.localTransactions)
          ..where((t) => t.clientTxnId.equals(clientTxnId) & t.notified.equals(false)))
        .write(const LocalTransactionsCompanion(notified: Value(true)));
    return changed == 1;
  }

  /// Takes one of today's [cap] prompt slots. A single conditional UPDATE, so two
  /// isolates syncing at the same moment cannot both take the last slot.
  Future<bool> takePromptSlot(String day, int cap) async {
    final key = '${SettingKeys.promptCountPrefix}$day';
    await db.customStatement("INSERT OR IGNORE INTO settings (\"key\", \"value\") VALUES (?, '0')", [key]);
    final taken = await db.customUpdate(
      'UPDATE settings SET "value" = CAST(CAST("value" AS INTEGER) + 1 AS TEXT) '
      'WHERE "key" = ? AND CAST("value" AS INTEGER) < ?',
      variables: [Variable.withString(key), Variable.withInt(cap)],
      updates: {db.settings},
    );
    // Counters of earlier days are no longer needed.
    await db.customStatement(
      'DELETE FROM settings WHERE "key" LIKE ? AND "key" <> ?',
      ['${SettingKeys.promptCountPrefix}%', key],
    );
    return taken == 1;
  }

  // --- unparsed bank messages --------------------------------------------------

  Future<void> addUnparsed(RawMessage message) async {
    await db.into(db.unparsedMessages).insert(
          UnparsedMessagesCompanion.insert(sender: message.sender, receivedAt: message.receivedAt, body: message.body),
        );
    await db.customStatement(
      'DELETE FROM unparsed_messages WHERE id NOT IN '
      '(SELECT id FROM unparsed_messages ORDER BY received_at DESC, id DESC LIMIT $unparsedCap)',
    );
  }

  Stream<List<UnparsedMessage>> watchUnparsed() => (db.select(db.unparsedMessages)
        ..orderBy([(m) => OrderingTerm.desc(m.receivedAt), (m) => OrderingTerm.desc(m.id)]))
      .watch();

  Future<int> unparsedCount() async {
    final count = db.unparsedMessages.id.count();
    final query = db.selectOnly(db.unparsedMessages)..addColumns([count]);
    return (await query.map((r) => r.read(count)).getSingle()) ?? 0;
  }

  // --- parser templates --------------------------------------------------------

  Future<void> saveTemplates(int version, List<Map<String, dynamic>> templates) {
    return db.transaction(() async {
      await db.delete(db.parserTemplates).go();
      for (final t in templates) {
        await db.into(db.parserTemplates).insert(
              ParserTemplatesCompanion.insert(id: Value((t['id'] as num).toInt()), json: jsonEncode(t)),
              mode: InsertMode.insertOrReplace,
            );
      }
      await setSetting(SettingKeys.templatesVersion, '$version');
    });
  }

  Future<List<ParserTemplate>> loadTemplates() async {
    final rows = await db.select(db.parserTemplates).get();
    final out = <ParserTemplate>[];
    for (final row in rows) {
      try {
        out.add(ParserTemplate.fromJson(asMap(jsonDecode(row.json))));
      } catch (_) {
        // A template this app version cannot read is skipped, not fatal.
      }
    }
    return out;
  }

  Future<int?> templatesVersion() async => int.tryParse(await getSetting(SettingKeys.templatesVersion) ?? '');

  // --- settings ----------------------------------------------------------------

  Future<String?> getSetting(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insert(SettingsCompanion.insert(key: key, value: value), mode: InsertMode.insertOrReplace);

  Future<void> removeSetting(String key) => (db.delete(db.settings)..where((s) => s.key.equals(key))).go();

  // --- answers waiting for a connection ---------------------------------------------

  /// Returns the id of the queued answer.
  Future<int> addPendingAction(String clientTxnId, String type) => db
      .into(db.pendingActions)
      .insert(PendingActionsCompanion.insert(clientTxnId: clientTxnId, type: type, createdAt: DateTime.now()));

  Future<List<PendingAction>> pendingActions() =>
      (db.select(db.pendingActions)..orderBy([(a) => OrderingTerm.asc(a.id)])).get();

  Future<void> removePendingAction(int id) => (db.delete(db.pendingActions)..where((a) => a.id.equals(id))).go();

  // --- wiping --------------------------------------------------------------------

  /// Removes everything captured: payments, unparsed messages, queued answers and
  /// prompt counters. Used when the private-analytics consent is withdrawn.
  /// Parser templates are not personal data and are kept.
  Future<void> wipeCaptured() {
    return db.transaction(() async {
      await db.delete(db.localTransactions).go();
      await db.delete(db.unparsedMessages).go();
      await db.delete(db.pendingActions).go();
      for (final key in SettingKeys.promptState) {
        await removeSetting(key);
      }
      await db.customStatement('DELETE FROM settings WHERE "key" LIKE ?', ['${SettingKeys.promptCountPrefix}%']);
    });
  }

  /// Removes everything, for sign-out and account deletion.
  Future<void> wipeAll() {
    return db.transaction(() async {
      await db.delete(db.localTransactions).go();
      await db.delete(db.unparsedMessages).go();
      await db.delete(db.pendingActions).go();
      await db.delete(db.parserTemplates).go();
      await db.delete(db.settings).go();
    });
  }
}

/// Keys of the key-value settings table.
class SettingKeys {
  const SettingKeys._();
  static const templatesVersion = 'templates_version';
  static const consents = 'consents';
  static const onboardingDone = 'onboarding_done';
  static const historyImported = 'history_imported';
  /// Followed by the day: how many prompts were shown that day.
  static const promptCountPrefix = 'prompt_count:';
  static const summaryIds = 'summary_ids';
  static const summaryAt = 'summary_at';
  static const userPhone = 'user_phone';

  static const promptState = [summaryIds, summaryAt, historyImported];
}
