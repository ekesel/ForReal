import '../../capture/derived.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/repositories.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../location/location_service.dart';

class SyncOutcome {
  /// Rows the server now holds, with what it said to ask.
  final List<AppliedResult> synced = [];

  /// Rows the server refused (HTTP 400). They stay on the device, marked failed.
  int failed = 0;

  /// A network error, 5xx or rate limit stopped the run. Try again later.
  bool retryLater = false;

  /// The server answered 403 with code consent_required: the private-analytics consent is missing.
  bool consentRequired = false;

  /// The session ended (refresh token rejected).
  bool signedOut = false;

  /// The server refused the request for another reason (for example a 403 that is
  /// not about consent). Rows stay pending; retrying at once would not help.
  ApiException? error;

  bool get clean => !retryLater && !consentRequired && !signedOut && error == null;
}

/// The outbox: uploads pending local payments and stores the server's answers.
///
/// Safe to run at any time and from any isolate. Every row carries a deterministic
/// client_txn_id, so sending one twice is answered with "duplicate", never stored twice.
class SyncService {
  SyncService({
    required this._store,
    required this._transactions,
    required this._merchants,
    required this._tagging,
    this._location = const NoLocation(),
    DateTime Function()? now,
    this.batchSize = 200,
  }) : _now = now ?? DateTime.now;

  final LocalStore _store;
  final TransactionsApi _transactions;
  final MerchantsApi _merchants;
  final TaggingApi _tagging;
  final LocationService _location;
  final DateTime Function() _now;

  /// The server accepts at most 200 rows per request.
  final int batchSize;

  Future<SyncOutcome>? _running;

  /// Uploads everything pending. Concurrent calls share one run.
  Future<SyncOutcome> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<SyncOutcome> _run() async {
    final outcome = SyncOutcome();
    await _replayAnswers(outcome);
    if (!outcome.clean) return outcome;

    var oneByOne = false;
    // Bounded: each pass either uploads rows, marks rows failed, or stops.
    for (var pass = 0; pass < 10000; pass++) {
      final batch = await _store.pending(limit: oneByOne ? 1 : batchSize);
      if (batch.isEmpty) break;
      try {
        final results = await _transactions.ingest([for (final row in batch) _toIngestRow(row)]);
        for (var i = 0; i < batch.length && i < results.length; i++) {
          outcome.synced.add(await _store.applyIngestResult(batch[i].clientTxnId, results[i]));
        }
        if (results.length < batch.length) {
          // Should not happen; avoid resending the tail forever.
          outcome.retryLater = true;
          break;
        }
      } on ApiException catch (e) {
        if (e.statusCode == 400) {
          final marked = await _markRejected(batch, e);
          outcome.failed += marked;
          if (marked == 0) {
            if (batch.length == 1) {
              await _store.markFailed(batch.single.clientTxnId, e.message);
              outcome.failed++;
            } else {
              // The response does not say which row is wrong: find it one at a time.
              oneByOne = true;
            }
          }
          continue;
        }
        _classify(e, outcome);
        break;
      }
    }
    return outcome;
  }

  IngestRow _toIngestRow(LocalTransaction row) {
    // A location is attached only when the app is on screen with a fresh fix, and
    // only to a payment that just happened: an old payment was not made "here".
    LatLng? location;
    if (!row.fromHistory && withinLocationWindow(row.receivedAt, _now())) {
      location = _location.recentFix();
    }
    return IngestRow(
      clientTxnId: row.clientTxnId,
      payeeName: row.payeeName,
      occurredOn: row.occurredOn,
      dayPart: row.dayPart.isNotEmpty ? row.dayPart : dayPart(row.receivedAt),
      amountBand: row.amountBand,
      source: row.source,
      ref: row.ref,
      location: location,
    );
  }

  /// Marks the rows the server named as invalid and returns how many there were.
  ///
  /// Django REST Framework reports errors of a list field per position. Depending on
  /// its version that is a map keyed by index, {"transactions": {"1": {"field": [...]}}},
  /// or a list with an empty entry for each valid row, {"transactions": [{}, {...}]}.
  Future<int> _markRejected(List<LocalTransaction> batch, ApiException e) async {
    final body = e.body;
    if (body is! Map) return 0;
    final errors = body['transactions'];
    final byIndex = <int, Map<dynamic, dynamic>>{};
    if (errors is Map) {
      errors.forEach((key, value) {
        final index = int.tryParse('$key');
        if (index != null && value is Map && value.isNotEmpty) byIndex[index] = value;
      });
    } else if (errors is List && errors.length == batch.length) {
      for (var i = 0; i < errors.length; i++) {
        final rowErrors = errors[i];
        if (rowErrors is Map && rowErrors.isNotEmpty) byIndex[i] = rowErrors;
      }
    }
    var marked = 0;
    for (final entry in byIndex.entries) {
      if (entry.key < 0 || entry.key >= batch.length) continue;
      await _store.markFailed(batch[entry.key].clientTxnId, _describe(entry.value));
      marked++;
    }
    return marked;
  }

  String _describe(Map<dynamic, dynamic> errors) {
    final parts = <String>[];
    errors.forEach((field, value) {
      final text = value is List ? value.join(' ') : '$value';
      parts.add(field == 'non_field_errors' ? text : '$field: $text');
    });
    return parts.join(' ');
  }

  /// Answers given from a notification while offline.
  Future<void> _replayAnswers(SyncOutcome outcome) async {
    for (final action in await _store.pendingActions()) {
      final row = await _store.get(action.clientTxnId);
      if (row == null) {
        await _store.removePendingAction(action.id);
        continue;
      }
      try {
        if (action.type == 'person' && row.payeeId != null) {
          await _merchants.resolveAsPerson(row.payeeId!);
          await _store.applyPayeeResolution(row.payeeId!, kind: 'person');
        } else if (action.type == 'confirm_items' && row.serverId != null) {
          await _store.setItems(row.clientTxnId, await _tagging.confirmItems(row.serverId!));
        } else if (row.syncState == 'pending') {
          // The payment itself is not uploaded yet; answer it on a later run.
          continue;
        }
        await _store.removePendingAction(action.id);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          outcome.signedOut = true;
          return;
        }
        if (e.isRetryable) {
          outcome.retryLater = true;
          return;
        }
        // The server will never accept it (payment gone, consent withdrawn): drop it.
        await _store.removePendingAction(action.id);
      }
    }
  }

  /// Pull to refresh: uploads what is pending, then brings every local row in line
  /// with the server's list. Restores payments after a reinstall (without amounts,
  /// which the server never had).
  Future<SyncOutcome> reconcile() async {
    final outcome = await run();
    if (!outcome.clean) return outcome;
    try {
      String? next;
      for (var page = 0; page < 1000; page++) {
        final result = await _transactions.list(next: next);
        for (final txn in result.results) {
          await _store.upsertFromServer(txn);
        }
        next = result.next;
        if (next == null) break;
      }
    } on ApiException catch (e) {
      _classify(e, outcome);
    }
    return outcome;
  }

  /// Why a run stopped. Only failures that can fix themselves ask for a retry.
  void _classify(ApiException e, SyncOutcome outcome) {
    if (e.statusCode == 401) {
      outcome.signedOut = true;
    } else if (e.isConsentRequired) {
      outcome.consentRequired = true;
    } else if (e.isRetryable) {
      outcome.retryLater = true;
    } else {
      outcome.error = e;
    }
  }
}

/// Exponential backoff for foreground retries: 5 s, 10 s, 20 s ... capped at 5 min.
Duration retryDelay(int attempt) {
  final seconds = 5 * (1 << attempt.clamp(0, 6));
  return Duration(seconds: seconds > 300 ? 300 : seconds);
}
