import 'package:intl/intl.dart';

/// "₹300", "₹55.50", "₹1,00,000": Indian grouping, paise only when there are any.
String formatRupees(double amount) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: whole ? 0 : 2).format(amount);
}

/// What to show when the exact amount is not on this device (a payment restored
/// from the server, which only ever had the band).
String bandLabel(String band) => switch (band) {
      'lt_50' => 'Under ₹50',
      '50_200' => '₹50 to 200',
      '200_500' => '₹200 to 500',
      'gt_500' => 'Above ₹500',
      _ => '',
    };

/// "2 Aug" for this year, "2 Aug 2025" otherwise. [isoDay] is yyyy-MM-dd.
String formatDay(String isoDay, {DateTime? today}) {
  final date = DateTime.tryParse(isoDay);
  if (date == null) return isoDay;
  final now = today ?? DateTime.now();
  return DateFormat(date.year == now.year ? 'd MMM' : 'd MMM yyyy').format(date);
}

/// "6:42 pm"
String formatTime(DateTime time) => DateFormat('h:mm a').format(time.toLocal()).toLowerCase();

/// "Today", "Yesterday", or "Sat, 2 Aug" for a calendar day.
String dayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(today.year, today.month, today.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(a.year == b.year ? 'EEE, d MMM' : 'd MMM yyyy').format(a);
}

/// "Today, 4:10 pm"
String dayAndTime(DateTime time, {DateTime? now}) => '${dayLabel(time.toLocal(), now: now)}, ${formatTime(time)}';

/// "tea-stall" → "Tea stall". Good enough to show a category without asking the server.
String categoryLabel(String slug) {
  final words = slug.replaceAll('-', ' ').trim();
  return words.isEmpty ? '' : words[0].toUpperCase() + words.substring(1);
}

/// "+91 98••• ••210": enough to recognise your own number, no more.
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return phone;
  final local = digits.substring(digits.length - 10);
  final country = digits.substring(0, digits.length - 10);
  return '${country.isEmpty ? '' : '+$country '}${local.substring(0, 2)}••• ••${local.substring(7)}';
}

/// A stable positive 31-bit id for a notification, from a client transaction id.
/// String.hashCode is not guaranteed stable across isolates, so hash by hand (FNV-1a).
int notificationId(String clientTxnId) {
  var hash = 0x811c9dc5;
  for (final unit in clientTxnId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  // 0 and 1 are reserved (1 is the daily summary).
  return id < 2 ? id + 2 : id;
}

const summaryNotificationId = 1;
