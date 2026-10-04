import '../../data/api/api_exception.dart';
import '../../data/api/repositories.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../notifications/prompts.dart';

/// "What did you buy?" for one payment.
class ItemsService {
  ItemsService({required this._store, required this._tagging, this._notifier = const SilentNotifier()});

  final LocalStore _store;
  final TaggingApi _tagging;
  final PromptNotifier _notifier;

  /// Chips for the shop's category (plus items that belong to no category).
  Future<List<Item>> chips(LocalTransaction row, {String? query}) =>
      _tagging.items(category: row.merchantInfo?.category, query: query);

  Future<ItemSuggestions> suggestions(LocalTransaction row) => _tagging.suggestions(_serverId(row));

  /// The one-tap "Yes, correct".
  Future<void> confirm(LocalTransaction row) async {
    final items = await _tagging.confirmItems(_serverId(row));
    await _store.setItems(row.clientTxnId, items);
    await _notifier.cancel(row.clientTxnId);
  }

  /// Replaces the tags with the user's selection.
  Future<void> save(LocalTransaction row, List<ItemEntry> entries) async {
    final items = await _tagging.setItems(_serverId(row), entries);
    await _store.setItems(row.clientTxnId, items);
    await _notifier.cancel(row.clientTxnId);
  }

  String _serverId(LocalTransaction row) {
    final id = row.serverId;
    if (id == null) {
      throw const ApiException(message: 'This payment has not reached the server yet. Try again in a moment.');
    }
    return id;
  }
}
