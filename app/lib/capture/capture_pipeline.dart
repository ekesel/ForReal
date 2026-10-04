import '../data/local_store.dart';
import '../data/models.dart';
import 'parser.dart';
import 'raw_message.dart';
import 'template_sync.dart';
import 'transaction_source.dart';

class CaptureReport {
  int payments = 0;
  int duplicates = 0;
  int credits = 0;
  int unparsed = 0;
  int dropped = 0;

  void add(CaptureReport other) {
    payments += other.payments;
    duplicates += other.duplicates;
    credits += other.credits;
    unparsed += other.unparsed;
    dropped += other.dropped;
  }
}

/// Turns raw bank messages into local payment rows. All parsing happens here, in
/// Dart; once a message is parsed its text is discarded and only the parsed fields
/// are kept.
class CapturePipeline {
  CapturePipeline({required this._source, required this._store, required this._templates});

  final TransactionSource _source;
  final LocalStore _store;
  final TemplateSync _templates;

  /// Nothing is captured without the private-analytics consent. The consent state
  /// is read from the local cache so this also works in the background.
  Future<bool> _mayCapture() async =>
      ConsentState.decode(await _store.getSetting(SettingKeys.consents)).has(Purpose.privateAnalytics);

  /// Processes everything the native side queued while Dart was not running.
  Future<CaptureReport> processQueue() async {
    final total = CaptureReport();
    // Bounded, so a message that can never be acknowledged cannot loop forever.
    for (var round = 0; round < 40; round++) {
      final batch = await _source.drainQueue();
      if (batch.isEmpty) break;
      final report = await process(batch);
      total.add(report);
      await _source.acknowledge(batch);
    }
    return total;
  }

  /// Parses and stores messages. Does not acknowledge them.
  Future<CaptureReport> process(List<RawMessage> messages, {bool fromHistory = false}) async {
    final report = CaptureReport();
    if (messages.isEmpty) return report;
    if (!await _mayCapture()) {
      report.dropped = messages.length;
      return report;
    }
    final parser = await _templates.cached();
    for (final message in messages) {
      switch (parser.parse(message)) {
        case ParsedDebit(:final payment):
          final inserted = await _store.insertParsed(payment, fromHistory: fromHistory);
          inserted ? report.payments++ : report.duplicates++;
        case IgnoredCredit():
          report.credits++;
        case Unparsed():
          // Kept on the device only, so new bank formats can be reported.
          await _store.addUnparsed(message);
          report.unparsed++;
        case NotABankMessage():
          report.dropped++;
      }
    }
    return report;
  }

  /// Imports bank messages already in the inbox, received at or after [since].
  /// Rows created here never raise a notification.
  Future<CaptureReport> importHistory(DateTime since) async {
    final total = CaptureReport();
    for (var page = 0; page < 200; page++) {
      final batch = await _source.history(since, page: page);
      if (batch.isEmpty) break;
      total.add(await process(batch, fromHistory: true));
    }
    return total;
  }
}
