import 'raw_message.dart';

/// Where payment messages come from. Android SMS today; the iOS module will be a
/// second implementation. Nothing above this layer may import platform code.
abstract class TransactionSource {
  /// Messages that arrive while the app is on screen.
  Stream<RawMessage> get messages;

  /// Messages queued natively while Dart was not running. They stay queued until
  /// [acknowledge] is called, so a crash in between loses nothing.
  Future<List<RawMessage>> drainQueue();

  /// Bank messages already on the device, oldest first, in pages starting at 0.
  /// An empty page means the end.
  Future<List<RawMessage>> history(DateTime since, {int page = 0});

  /// Removes processed messages from the native queue.
  Future<void> acknowledge(List<RawMessage> processed);
}

enum SmsPermission { granted, denied, deniedForever }

/// Switches and settings of the capture module that are not message streams.
abstract class CaptureControl {
  /// Bank sender codes from the parser templates. Anything else is dropped natively.
  Future<void> setAllowedSenders(Set<String> codes);

  /// Capture is off until the private-analytics consent is granted.
  Future<void> setCaptureEnabled(bool enabled);

  /// Forgets every queued message.
  Future<void> clearQueue();

  Future<SmsPermission> smsPermission();

  Future<SmsPermission> requestSmsPermission();

  /// Tells the platform which Dart function to run for background processing.
  Future<void> registerBackgroundEntryPoint();
}
