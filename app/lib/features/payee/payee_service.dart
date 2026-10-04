import 'package:drift/drift.dart' show Value;

import '../../data/api/api_exception.dart';
import '../../data/api/repositories.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../location/location_service.dart';
import '../notifications/prompts.dart';

/// "Shop or person?" The answer applies to every payment to that payee, on the
/// server and in the local database.
class PayeeService {
  PayeeService({
    required this._store,
    required this._merchants,
    required this._transactions,
    this._location = const NoLocation(),
    this._notifier = const SilentNotifier(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LocalStore _store;
  final MerchantsApi _merchants;
  final TransactionsApi _transactions;
  final LocationService _location;
  final PromptNotifier _notifier;
  final DateTime Function() _now;

  /// "Where the user is now" counts as where the payment happened only shortly
  /// after it. Later than that, no location is sent at all.
  Future<LatLng?> hereFor(LocalTransaction row) async {
    if (!withinLocationWindow(row.receivedAt, _now())) return null;
    return _location.currentFix();
  }

  Future<List<Merchant>> suggestions(LocalTransaction row, {LatLng? here}) =>
      _merchants.suggestions(_payeeId(row), near: here);

  Future<List<Merchant>> search(String query, {LatLng? here}) => _merchants.search(query, near: here);

  Future<List<Category>> categories() => _merchants.categories();

  Future<void> markPerson(LocalTransaction row) async {
    final payeeId = _payeeId(row);
    await _merchants.resolveAsPerson(payeeId);
    await _store.applyPayeeResolution(payeeId, kind: 'person');
    await _cancelPrompts(payeeId);
  }

  Future<void> chooseMerchant(LocalTransaction row, Merchant merchant, {LatLng? here}) async {
    final result = await _merchants.resolveAsMerchant(_payeeId(row), merchant.id, here: here);
    await _applyMerchant(row, result, here);
  }

  Future<void> addMerchant(LocalTransaction row, NewMerchant merchant, {LatLng? here}) async {
    final result = await _merchants.resolveAsNewMerchant(_payeeId(row), merchant, here: here);
    await _applyMerchant(row, result, here);
  }

  int _payeeId(LocalTransaction row) {
    final id = row.payeeId;
    if (id == null) {
      throw const ApiException(message: 'This payment has not reached the server yet. Try again in a moment.');
    }
    return id;
  }

  Future<void> _applyMerchant(LocalTransaction row, ResolveResult result, LatLng? here) async {
    final payeeId = _payeeId(row);
    await _store.applyPayeeResolution(payeeId, kind: 'merchant', merchant: result.merchant);
    await _cancelPrompts(payeeId);
    if (here != null && row.serverId != null) {
      try {
        await _transactions.setLocation(row.serverId!, here);
      } on ApiException {
        // The shop answer is saved; a missing location is not worth failing for.
      }
    }
    await refreshPayee(payeeId);
  }

  /// The server tagged these payments with its guesses when the shop was set:
  /// fetch them so the list shows the guesses straight away.
  Future<void> refreshPayee(int payeeId) async {
    final rows = await _store.byPayee(payeeId);
    rows.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    for (final local in rows.take(50)) {
      final serverId = local.serverId;
      if (serverId == null) continue;
      try {
        final txn = await _transactions.get(serverId);
        await _store.upsertFromServer(txn, ask: Value(LocalStore.defaultAsk(txn.kind, txn.items)));
      } on ApiException {
        return; // Pull to refresh will catch up.
      }
    }
  }

  Future<void> _cancelPrompts(int payeeId) async {
    for (final row in await _store.byPayee(payeeId)) {
      await _notifier.cancel(row.clientTxnId);
    }
  }
}
