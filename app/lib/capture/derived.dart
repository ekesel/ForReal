import 'package:uuid/uuid.dart';

/// Fields the server receives instead of the facts that stay on the device.

/// The server stores a band, never the amount.
String amountBand(double amount) {
  if (amount < 50) return 'lt_50';
  if (amount < 200) return '50_200';
  if (amount < 500) return '200_500';
  return 'gt_500';
}

/// Part of the day, from the local time the message was received.
String dayPart(DateTime receivedAt) {
  final hour = receivedAt.toLocal().hour;
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/// Namespace for ForReal client transaction ids. Never change it: ids must stay
/// stable so that re-importing a message is recognised as the same payment.
const _namespace = '6f1d2c9e-5a70-4c5b-9c0e-7b0a5f0e4d21';

/// Deterministic id (UUIDv5) of a message: the same sender, timestamp and text
/// always give the same id, so capturing or importing it twice is harmless.
String clientTxnId({required String sender, required DateTime receivedAt, required String body}) {
  final name = '${sender.trim().toUpperCase()}|${receivedAt.millisecondsSinceEpoch}|$body';
  return const Uuid().v5(_namespace, name);
}

/// 'yyyy-MM-dd' for the ingest API.
String isoDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

/// Payee as shown on screen: runs of whitespace become one space.
String collapseWhitespace(String value) => value.trim().split(RegExp(r'\s+')).join(' ');
