import '../data/local_store.dart';
import '../data/secret_store.dart';
import '../features/notifications/prompts.dart';
import '../features/sync/sync_service.dart';
import 'capture_pipeline.dart';
import 'template_sync.dart';

/// One background run, started by the platform after a bank message arrived (or
/// periodically): parse the queue, upload, notify. Runs with the app closed.
class BackgroundRunner {
  BackgroundRunner({
    required this._tokens,
    required this._store,
    required this._templates,
    required this._pipeline,
    required this._sync,
    required this._prompts,
  });

  final TokenStore _tokens;
  final LocalStore _store;
  final TemplateSync _templates;
  final CapturePipeline _pipeline;
  final SyncService _sync;
  final PromptService _prompts;

  /// Returns true when another run should follow once there is a connection.
  Future<bool> run({required String reason}) async {
    if (await _tokens.load() == null) return false;
    if (reason == 'periodic' || (await _store.loadTemplates()).isEmpty) {
      await _templates.sync();
    }
    await _pipeline.processQueue();
    final outcome = await _sync.run();
    await _prompts.afterSync(outcome.synced);
    return outcome.retryLater;
  }
}
