import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:forreal/capture/parser.dart';
import 'package:forreal/capture/raw_message.dart';
import 'package:forreal/capture/transaction_source.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/location/location_service.dart';
import 'package:forreal/features/notifications/prompts.dart';

LocalStore memoryStore() {
  // Tests open one in-memory database each, sometimes two in one test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return LocalStore(AppDatabase(NativeDatabase.memory()));
}

const hdfcTemplate = {
  'id': 1,
  'bank': 'HDFC',
  'name': 'HDFC UPI debit (Sent Rs)',
  'sender_ids': ['HDFCBK'],
  'source': 'sms',
  'txn_type': 'debit',
  'pattern': r'Sent Rs\.(?<amount>[\d,]+(?:\.\d{1,2})?)\s+'
      r'From HDFC Bank A/C \*(?<account>\d{4})\s+'
      r'To (?<payee>.+?)\s+'
      r'On (?<date>\d{2}/\d{2}/\d{2})\s+'
      r'Ref (?<ref>\d+)',
  'flags': 's',
  'date_format': 'dd/MM/yy',
  'priority': 10,
};

String hdfcSms({String amount = '300.00', String payee = 'RAMESH  KUMAR', String ref = '400012345678'}) =>
    'Sent Rs.$amount\nFrom HDFC Bank A/C *1234\nTo $payee\nOn 02/08/26\nRef $ref\n'
    'Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808';

ParsedPayment parsed(String id, {double amount = 300, DateTime? at, String ref = '', String payee = 'RAMESH  KUMAR'}) =>
    ParsedPayment(
      clientTxnId: id,
      bank: 'HDFC',
      payeeName: payee,
      amount: amount,
      occurredOn: DateTime(2026, 8, 2),
      receivedAt: at ?? DateTime(2026, 8, 2, 18, 30),
      ref: ref,
    );

const teaStall = {'id': 'm-1', 'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false, 'location': null};

Map<String, dynamic> guess(String name, {bool inferred = true, int quantity = 1, int id = 3}) => {
      'item': {'id': id, 'name': name, 'category': 'tea-stall'},
      'quantity': quantity,
      'origin': inferred ? 'ai_category' : 'user',
      'confidence': inferred ? 0.5 : 1.0,
      'inferred': inferred,
    };

Map<String, dynamic> serverTxn(
  String clientId, {
  String? id,
  String kind = 'unknown',
  Map<String, dynamic>? merchant,
  List<Map<String, dynamic>> items = const [],
  int payee = 7,
}) =>
    {
      'id': id ?? 's-$clientId',
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

Map<String, dynamic> ingestResult(Map<String, dynamic> txn, {String status = 'created', String? ask = 'payee'}) =>
    {'status': status, 'transaction': txn, 'ask': ask, 'payee_suggestions': <dynamic>[]};

/// An in-memory native queue.
class FakeSource implements TransactionSource, CaptureControl {
  final List<RawMessage> queue = [];
  final List<RawMessage> inbox = [];
  final List<int> acknowledged = [];
  Set<String> allowedSenders = {};
  bool captureEnabled = false;
  bool queueCleared = false;
  SmsPermission permission = SmsPermission.granted;
  int _nextId = 1;

  void enqueue(String sender, String body, {DateTime? at}) =>
      queue.add(RawMessage(sender: sender, receivedAt: at ?? DateTime(2026, 8, 2, 18, 30), body: body, queueId: _nextId++));

  @override
  Stream<RawMessage> get messages => const Stream.empty();

  @override
  Future<List<RawMessage>> drainQueue() async => queue.take(50).toList();

  @override
  Future<void> acknowledge(List<RawMessage> processed) async {
    for (final m in processed) {
      acknowledged.add(m.queueId!);
      queue.removeWhere((q) => q.queueId == m.queueId);
    }
  }

  @override
  Future<List<RawMessage>> history(DateTime since, {int page = 0}) async {
    final matching = [for (final m in inbox) if (!m.receivedAt.isBefore(since)) m];
    return matching.skip(page * 2).take(2).toList();
  }

  @override
  Future<void> setAllowedSenders(Set<String> codes) async => allowedSenders = codes;

  @override
  Future<void> setCaptureEnabled(bool enabled) async => captureEnabled = enabled;

  @override
  Future<void> clearQueue() async {
    queue.clear();
    queueCleared = true;
  }

  @override
  Future<SmsPermission> smsPermission() async => permission;

  int permissionRequests = 0;

  /// What the Android prompt answers; defaults to the current state.
  SmsPermission? promptAnswer;

  @override
  Future<SmsPermission> requestSmsPermission() async {
    permissionRequests++;
    return permission = promptAnswer ?? permission;
  }

  int backgroundRegistrations = 0;

  @override
  Future<void> registerBackgroundEntryPoint() async => backgroundRegistrations++;
}

class RecordingNotifier implements PromptNotifier {
  final List<String> shown = [];
  final List<({int count, DateTime at})> summaries = [];
  final List<String> cancelled = [];
  bool cancelledAll = false;

  @override
  Future<void> showPayeePrompt({required String clientTxnId, required String title, required String body}) async =>
      shown.add('payee|$clientTxnId|$title|$body');

  @override
  Future<void> showItemsPrompt({
    required String clientTxnId,
    required String title,
    required String body,
    required bool hasGuess,
  }) async =>
      shown.add('items|$clientTxnId|$title|$body|$hasGuess');

  @override
  Future<void> scheduleSummary({required int count, required DateTime at}) async => summaries.add((count: count, at: at));

  @override
  Future<void> cancel(String clientTxnId) async => cancelled.add(clientTxnId);

  @override
  Future<void> cancelAll() async => cancelledAll = true;
}

class FixedLocation implements LocationService {
  FixedLocation({this.recent, this.current});
  LatLng? recent;
  LatLng? current;
  int fixes = 0;

  @override
  LatLng? recentFix({Duration maxAge = const Duration(minutes: 2)}) => recent;

  @override
  Future<LatLng?> currentFix() async {
    fixes++;
    return current;
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> openSettings() async {}
}

Future<void> grantConsents(LocalStore store, {bool privateAnalytics = true, bool location = false}) => store.setSetting(
      SettingKeys.consents,
      ConsentState({'private_analytics': privateAnalytics, 'location': location}).encode(),
    );
