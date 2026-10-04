import '../data/api/api_exception.dart';
import '../data/api/repositories.dart';
import '../data/local_store.dart';
import 'parser.dart';
import 'transaction_source.dart';

/// Keeps the cached parser templates current and tells the native filter which
/// bank senders exist. Only senders named in these templates are ever captured.
class TemplateSync {
  TemplateSync({required this._api, required this._store, required this._control});

  final TemplatesApi _api;
  final LocalStore _store;
  final CaptureControl _control;

  /// Parser built from the cache. No network.
  Future<MessageParser> cached() async => MessageParser(await _store.loadTemplates());

  /// Downloads templates when the server version changed. When the server cannot
  /// be reached the cached templates keep working.
  Future<MessageParser> sync() async {
    try {
      final known = await _store.templatesVersion();
      final response = await _api.fetch(knownVersion: known);
      if (response.changed) {
        await _store.saveTemplates(response.version, response.templates);
      }
    } on ApiException {
      // Offline or server trouble: fall through to the cache.
    }
    final parser = await cached();
    await _control.setAllowedSenders(parser.senderCodes);
    return parser;
  }
}
