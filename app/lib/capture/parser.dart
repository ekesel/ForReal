import 'derived.dart';
import 'raw_message.dart';
import 'sender_matcher.dart';

/// One bank message shape, downloaded from the server (GET parser-templates/).
class ParserTemplate {
  ParserTemplate({
    required this.id,
    required this.bank,
    required this.name,
    required this.senderIds,
    required this.source,
    required this.txnType,
    required this.pattern,
    required this.flags,
    required this.dateFormat,
    required this.priority,
  });

  final int id;
  final String bank;
  final String name;
  final List<String> senderIds;
  final String source;

  /// 'debit' or 'credit'. Credits are recognised only so they can be ignored.
  final String txnType;

  /// Dart-dialect regex with named groups: amount, payee, optionally date, ref, account.
  final String pattern;

  /// 's' = dot matches newline, 'i' = ignore case.
  final String flags;
  final String dateFormat;
  final int priority;

  factory ParserTemplate.fromJson(Map<String, dynamic> json) => ParserTemplate(
        id: (json['id'] as num).toInt(),
        bank: json['bank'] as String? ?? '',
        name: json['name'] as String? ?? '',
        senderIds: [for (final s in json['sender_ids'] as List? ?? const []) s as String],
        source: json['source'] as String? ?? 'sms',
        txnType: json['txn_type'] as String? ?? 'debit',
        pattern: json['pattern'] as String,
        flags: json['flags'] as String? ?? '',
        dateFormat: json['date_format'] as String? ?? '',
        priority: (json['priority'] as num?)?.toInt() ?? 100,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank': bank,
        'name': name,
        'sender_ids': senderIds,
        'source': source,
        'txn_type': txnType,
        'pattern': pattern,
        'flags': flags,
        'date_format': dateFormat,
        'priority': priority,
      };

  RegExp? _regex;
  bool _broken = false;

  /// Null when the pattern does not compile; such a template is skipped.
  RegExp? get regex {
    if (_regex != null || _broken) return _regex;
    try {
      _regex = RegExp(pattern, dotAll: flags.contains('s'), caseSensitive: !flags.contains('i'));
    } on FormatException {
      _broken = true;
    }
    return _regex;
  }
}

/// A payment read from a message. The exact amount stays in the local database.
class ParsedPayment {
  const ParsedPayment({
    required this.clientTxnId,
    required this.bank,
    required this.payeeName,
    required this.amount,
    required this.occurredOn,
    required this.receivedAt,
    required this.ref,
  });

  final String clientTxnId;
  final String bank;

  /// Exactly as the bank wrote it (trimmed). Sent to the server as payee_name.
  final String payeeName;
  final double amount;

  /// Calendar date of the payment.
  final DateTime occurredOn;
  final DateTime receivedAt;
  final String ref;

  String get payeeDisplay => collapseWhitespace(payeeName);
}

sealed class ParseOutcome {
  const ParseOutcome();
}

/// A payment the user made.
class ParsedDebit extends ParseOutcome {
  const ParsedDebit(this.payment);
  final ParsedPayment payment;
}

/// Money received: recognised and deliberately ignored.
class IgnoredCredit extends ParseOutcome {
  const IgnoredCredit();
}

/// From a bank sender, but no template matched (OTP, promotion, or a new format).
class Unparsed extends ParseOutcome {
  const Unparsed();
}

/// Not from a sender named in any template. Must never be stored.
class NotABankMessage extends ParseOutcome {
  const NotABankMessage();
}

class MessageParser {
  MessageParser(List<ParserTemplate> templates)
      : _templates = [...templates]..sort((a, b) {
            final byPriority = a.priority.compareTo(b.priority);
            return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
          });

  final List<ParserTemplate> _templates;

  /// Every sender code named by a template: the allow-list for the native filter.
  Set<String> get senderCodes => {
        for (final t in _templates)
          for (final s in t.senderIds)
            if (s.trim().isNotEmpty) s.trim().toUpperCase(),
      };

  ParseOutcome parse(RawMessage message) {
    final candidates = [
      for (final t in _templates)
        if (matchSenderCode(message.sender, t.senderIds) != null) t,
    ];
    if (candidates.isEmpty) return const NotABankMessage();

    for (final template in candidates) {
      final match = template.regex?.firstMatch(message.body);
      if (match == null) continue;
      if (template.txnType == 'credit') return const IgnoredCredit();
      final payment = _payment(template, match, message);
      if (payment != null) return ParsedDebit(payment);
    }
    return const Unparsed();
  }

  ParsedPayment? _payment(ParserTemplate template, RegExpMatch match, RawMessage message) {
    final amount = parseAmount(_group(match, 'amount'));
    final payee = _group(match, 'payee')?.trim() ?? '';
    if (amount == null || payee.isEmpty) return null;
    final received = message.receivedAt.toLocal();
    final receivedDay = DateTime(received.year, received.month, received.day);
    var occurredOn = parseTemplateDate(_group(match, 'date'), template.dateFormat) ?? receivedDay;
    // A bank reports a payment within moments. A date far from the day the message
    // arrived means the format was misread, so trust the arrival day instead.
    if (occurredOn.difference(receivedDay).inDays.abs() > 3) occurredOn = receivedDay;
    final ref = (_group(match, 'ref') ?? '').trim();
    return ParsedPayment(
      clientTxnId: clientTxnId(sender: message.sender, receivedAt: message.receivedAt, body: message.body),
      bank: template.bank,
      payeeName: payee.length > 140 ? payee.substring(0, 140) : payee,
      amount: amount,
      occurredOn: occurredOn,
      receivedAt: message.receivedAt,
      ref: ref.length > 40 ? ref.substring(0, 40) : ref,
    );
  }

  String? _group(RegExpMatch match, String name) =>
      match.groupNames.contains(name) ? match.namedGroup(name) : null;
}

/// "1,00,000.50" → 100000.5. Null when the text is not a positive amount.
double? parseAmount(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0 || !value.isFinite) return null;
  return value;
}

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// Reads a date written in a template's `date_format` (tokens: d, dd, M, MM, MMM,
/// yy, yyyy; anything else is a literal). Null when it does not fit.
DateTime? parseTemplateDate(String? value, String format) {
  if (value == null || value.isEmpty || format.isEmpty) return null;
  int? day, month, year;
  var pos = 0;
  var i = 0;

  int? digits(int min, int max) {
    var end = pos;
    while (end < value.length && end - pos < max && _isDigit(value.codeUnitAt(end))) {
      end++;
    }
    if (end - pos < min) return null;
    final n = int.parse(value.substring(pos, end));
    pos = end;
    return n;
  }

  while (i < format.length) {
    final ch = format[i];
    var run = 1;
    while (i + run < format.length && format[i + run] == ch) {
      run++;
    }
    if (ch == 'd') {
      day = digits(run >= 2 ? 2 : 1, 2);
      if (day == null) return null;
    } else if (ch == 'M' && run >= 3) {
      if (pos + 3 > value.length) return null;
      final index = _months.indexOf(value.substring(pos, pos + 3).toLowerCase());
      if (index < 0) return null;
      month = index + 1;
      pos += 3;
      // Full month names: skip the remaining letters.
      while (run > 3 && pos < value.length && RegExp(r'[A-Za-z]').hasMatch(value[pos])) {
        pos++;
      }
    } else if (ch == 'M') {
      month = digits(run >= 2 ? 2 : 1, 2);
      if (month == null) return null;
    } else if (ch == 'y') {
      if (run >= 4) {
        year = digits(4, 4);
      } else {
        final short = digits(2, 2);
        year = short == null ? null : 2000 + short;
      }
      if (year == null) return null;
    } else {
      // Literal: must be present as written.
      for (var k = 0; k < run; k++) {
        if (pos >= value.length || value[pos] != ch) return null;
        pos++;
      }
    }
    i += run;
  }
  if (pos != value.length || day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  // DateTime rolls 31/02 over into March; reject instead.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
