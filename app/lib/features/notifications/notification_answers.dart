import '../../data/api/api_exception.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../items/items_service.dart';
import '../payee/payee_service.dart';

/// Answers given straight from a notification button, with the app closed.
///
/// The answer is stored locally and queued first, then sent. If sending fails for
/// lack of a connection (or the isolate is killed), the next sync replays it. The user is never asked the same thing twice because the
/// network was down.
class NotificationAnswers {
  NotificationAnswers({required this._store, required this._payees, required this._items});

  final LocalStore _store;
  final PayeeService _payees;
  final ItemsService _items;

  /// [Person] on the payee prompt, [Not a shop] on the items prompt.
  Future<void> person(String clientTxnId) async {
    final row = await _store.get(clientTxnId);
    final payeeId = row?.payeeId;
    if (row == null || payeeId == null) return;
    // Record the answer before touching the network: the background isolate that
    // runs this can be killed at any moment, and the notification is already gone.
    final queued = await _store.addPendingAction(clientTxnId, 'person');
    await _store.applyPayeeResolution(payeeId, kind: 'person');
    try {
      await _payees.markPerson(row);
      await _store.removePendingAction(queued);
    } on ApiException catch (e) {
      // Retryable: stays queued and the next sync replays it.
      if (!e.isRetryable) await _store.removePendingAction(queued);
    }
  }

  /// [Yes] on the items prompt: the guess was right.
  Future<void> confirmItems(String clientTxnId) async {
    final row = await _store.get(clientTxnId);
    if (row == null || row.serverId == null) return;
    final before = row.taggedItems;
    final queued = await _store.addPendingAction(clientTxnId, 'confirm_items');
    await _store.setItems(clientTxnId, [
      for (final tag in before)
        TaggedItem(item: tag.item, quantity: tag.quantity, origin: 'user', confidence: 1, inferred: false),
    ]);
    try {
      await _items.confirm(row);
      await _store.removePendingAction(queued);
    } on ApiException catch (e) {
      if (!e.isRetryable) {
        // The server will never accept it: undo the optimistic change.
        await _store.removePendingAction(queued);
        await _store.setItems(clientTxnId, before);
      }
    }
  }
}

/// Routes a background button to its answer. Returns false for buttons that open the app.
Future<bool> answerNotificationAction(NotificationAnswers answers, String? action, String clientTxnId) async {
  switch (action) {
    case 'person' || 'not_shop':
      await answers.person(clientTxnId);
      return true;
    case 'yes':
      await answers.confirmItems(clientTxnId);
      return true;
    default:
      return false;
  }
}
