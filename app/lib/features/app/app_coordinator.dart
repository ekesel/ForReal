import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/capture_pipeline.dart';
import '../../capture/raw_message.dart';
import '../../core/isolate_ping.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../session/session_controller.dart';
import '../sync/sync_service.dart';

/// Whether the app is on screen. Location is only ever read while it is.
class AppForeground {
  bool value = true;
}

final appForegroundProvider = Provider<AppForeground>((ref) => AppForeground());

/// Emits whenever the device gets a connection. Overridden with the real signal at start-up.
final onlineChangesProvider = Provider<Stream<void>>((ref) => const Stream.empty());

/// True while a history import is running, for the progress line on the home screen.
class HistoryImportState extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool running) => state = running;
}

final historyImportRunningProvider = NotifierProvider<HistoryImportState, bool>(HistoryImportState.new);

/// The foreground runtime: reacts to new messages, app resume and connectivity by
/// processing the capture queue and running the outbox, and retries with backoff.
class AppCoordinator {
  AppCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<RawMessage>? _messages;
  StreamSubscription<void>? _online;
  ReceivePort? _port;
  Timer? _retry;
  int _attempt = 0;
  bool _started = false;

  SessionState get _session => _ref.read(sessionProvider);
  CapturePipeline get _pipeline => _ref.read(capturePipelineProvider);

  void start() {
    if (_started) return;
    _started = true;
    _port = listenForBackgroundChanges(refreshUi);
    _messages = _ref.read(transactionSourceProvider).messages.listen(_onLiveMessage, onError: (_) {});
    _online = _ref.read(onlineChangesProvider).listen((_) => kick());
  }

  void dispose() {
    _messages?.cancel();
    _online?.cancel();
    _retry?.cancel();
    final port = _port;
    if (port != null) stopListeningForBackgroundChanges(port);
    _started = false;
  }

  /// A background isolate changed the database: make every watching screen re-read.
  void refreshUi() {
    final db = _ref.read(databaseProvider);
    db.markTablesUpdated(db.allTables);
  }

  /// App start and every return to the foreground.
  Future<void> onResume() async {
    _ref.read(appForegroundProvider).value = true;
    if (!_session.signedIn) return;
    refreshUi();
    await _ref.read(sessionProvider.notifier).refreshConsents();
    if (!_session.mayCapture) return;
    if (_session.consents.has(Purpose.location)) {
      // Take a fix now so a payment that syncs in the next two minutes can carry it.
      _ref.read(locationServiceProvider).currentFix().ignore();
    }
    try {
      await _pipeline.processQueue();
    } catch (_) {
      // The queue stays intact; the next trigger processes it.
    }
    await kick();
  }

  void onPause() {
    _ref.read(appForegroundProvider).value = false;
  }

  Future<void> _onLiveMessage(RawMessage message) async {
    if (!_session.mayCapture) return;
    await _pipeline.process([message]);
    await _ref.read(transactionSourceProvider).acknowledge([message]);
    await kick();
  }

  /// Runs the outbox now. Schedules a retry with backoff if the server was not reachable.
  Future<SyncOutcome?> kick() async {
    if (!_session.mayCapture) return null;
    _retry?.cancel();
    final outcome = await _ref.read(syncServiceProvider).run();
    await _afterSync(outcome);
    return outcome;
  }

  /// Pull to refresh.
  Future<SyncOutcome?> reconcile() async {
    if (!_session.mayCapture) return null;
    _retry?.cancel();
    final outcome = await _ref.read(syncServiceProvider).reconcile();
    await _afterSync(outcome);
    return outcome;
  }

  Future<void> _afterSync(SyncOutcome outcome) async {
    await _ref.read(promptServiceProvider).afterSync(outcome.synced);
    if (outcome.consentRequired) {
      // The server says the consent is gone: reload it. The router then shows the consent screen.
      await _ref.read(sessionProvider.notifier).refreshConsents();
      return;
    }
    if (outcome.retryLater) {
      _retry = Timer(retryDelay(_attempt++), kick);
    } else {
      _attempt = 0;
    }
  }

  /// Imports bank messages received in the last [period] and uploads them. No notifications.
  Future<int> importHistory(Duration period) async {
    if (!_session.mayCapture) return 0;
    final running = _ref.read(historyImportRunningProvider.notifier);
    running.set(true);
    try {
      await _ref.read(templateSyncProvider).sync();
      final report = await _pipeline.importHistory(DateTime.now().subtract(period));
      await kick();
      return report.payments;
    } finally {
      running.set(false);
    }
  }
}

final appCoordinatorProvider = Provider<AppCoordinator>((ref) {
  final coordinator = AppCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
