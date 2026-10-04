import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/derived.dart';
import 'package:forreal/capture/parser.dart';
import 'package:forreal/capture/raw_message.dart';
import 'package:forreal/capture/sender_matcher.dart';

/// The template seeded by backend/apps/parsers/migrations/0002_seed_hdfc.py.
final hdfcDebit = ParserTemplate.fromJson({
  'id': 1,
  'bank': 'HDFC',
  'name': 'HDFC UPI debit (Sent Rs)',
  'sender_ids': ['HDFCBK'],
  'source': 'sms',
  'txn_type': 'debit',
  'pattern': r'Sent Rs\.(?<amount>[\d,]+(?:\.\d{1,2})?)\s+'
      r'From HDFC Bank A/C \*(?<account>\d{4})\s+'
      r'To (?<payee>.+?)\s+'
      r'On (?<date>\d{2}/\d{2}/\d{2})\s+'
      r'Ref (?<ref>\d+)',
  'flags': 's',
  'date_format': 'dd/MM/yy',
  'priority': 10,
});

final hdfcCredit = ParserTemplate.fromJson({
  'id': 2,
  'bank': 'HDFC',
  'name': 'HDFC credit',
  'sender_ids': ['HDFCBK'],
  'txn_type': 'credit',
  'pattern': r'Rs\.(?<amount>[\d,.]+) credited to HDFC Bank A/C \*\d{4} from (?<payee>.+)',
  'flags': 'i',
  'date_format': '',
  'priority': 20,
});

const sample = 'Sent Rs.300.00\nFrom HDFC Bank A/C *1234\nTo RAMESH  KUMAR\nOn 02/08/26\nRef 400012345678\n'
    'Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808';

RawMessage sms(String body, {String sender = 'AD-HDFCBK', DateTime? at}) =>
    RawMessage(sender: sender, receivedAt: at ?? DateTime(2026, 8, 2, 18, 30), body: body);

String debit(String amount, {String date = '02/08/26'}) =>
    'Sent Rs.$amount\nFrom HDFC Bank A/C *1234\nTo RAMESH KUMAR\nOn $date\nRef 400012345678';

void main() {
  final parser = MessageParser([hdfcCredit, hdfcDebit]);

  group('seeded HDFC template', () {
    test('parses the sample message', () {
      final outcome = parser.parse(sms(sample));
      expect(outcome, isA<ParsedDebit>());
      final p = (outcome as ParsedDebit).payment;
      expect(p.bank, 'HDFC');
      expect(p.amount, 300.0);
      expect(p.payeeName, 'RAMESH  KUMAR', reason: 'original spacing is kept for the server');
      expect(p.payeeDisplay, 'RAMESH KUMAR');
      expect(p.occurredOn, DateTime(2026, 8, 2));
      expect(p.ref, '400012345678');
    });

    test('matches every sender form of the bank', () {
      for (final sender in ['HDFCBK', 'AD-HDFCBK', 'VM-HDFCBK-S', 'jd-hdfcbk']) {
        expect(parser.parse(sms(sample, sender: sender)), isA<ParsedDebit>(), reason: sender);
      }
    });

    test('an OTP from the bank is not a payment', () {
      final outcome = parser.parse(sms('123456 is your OTP for txn of Rs.300.00 at HDFC Bank. Do not share.'));
      expect(outcome, isA<Unparsed>());
    });

    test('a credit is recognised and ignored', () {
      final outcome = parser.parse(sms('Rs.500.00 credited to HDFC Bank A/C *1234 from VPA x@okaxis'));
      expect(outcome, isA<IgnoredCredit>());
    });

    test('a credit without a credit template is simply unparsed', () {
      final debitOnly = MessageParser([hdfcDebit]);
      expect(debitOnly.parse(sms('Rs.500.00 credited to HDFC Bank A/C *1234 from VPA x@okaxis')), isA<Unparsed>());
    });

    test('a message from a sender in no template is not a bank message', () {
      expect(parser.parse(sms(sample, sender: 'AD-ICICIB')), isA<NotABankMessage>());
      expect(parser.parse(sms(sample, sender: '+919876543210')), isA<NotABankMessage>());
    });
  });

  group('amounts', () {
    double? amountOf(String text) {
      final outcome = parser.parse(sms(debit(text)));
      return outcome is ParsedDebit ? outcome.payment.amount : null;
    }

    test('commas are removed, Indian and western grouping alike', () {
      expect(amountOf('1,250.50'), 1250.5);
      expect(amountOf('1,00,000.00'), 100000.0);
      expect(amountOf('12,34,567'), 1234567.0);
      expect(amountOf('55'), 55.0);
    });

    test('text that is not an amount is rejected', () {
      expect(parseAmount(','), isNull);
      expect(parseAmount('1.2.3'), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('0.00'), isNull);
      expect(parseAmount('12,'), 12.0);
      expect(parseAmount(null), isNull);
    });

    test('a match with an unusable amount does not become a payment', () {
      expect(parser.parse(sms(debit(',,,'))), isA<Unparsed>());
    });
  });

  group('amount band', () {
    test('edges', () {
      expect(amountBand(0.01), 'lt_50');
      expect(amountBand(49.99), 'lt_50');
      expect(amountBand(50), '50_200');
      expect(amountBand(199.99), '50_200');
      expect(amountBand(200), '200_500');
      expect(amountBand(499.99), '200_500');
      expect(amountBand(500), 'gt_500');
      expect(amountBand(100000), 'gt_500');
    });
  });

  group('day part', () {
    test('uses the local hour the message was received', () {
      String at(int hour, [int minute = 0]) => dayPart(DateTime(2026, 8, 2, hour, minute));
      expect(at(4, 59), 'night');
      expect(at(5), 'morning');
      expect(at(11, 59), 'morning');
      expect(at(12), 'afternoon');
      expect(at(16, 59), 'afternoon');
      expect(at(17), 'evening');
      expect(at(20, 59), 'evening');
      expect(at(21), 'night');
      expect(at(0), 'night');
    });
  });

  group('dates', () {
    test('falls back to the day the message arrived', () {
      final noDate = ParserTemplate.fromJson({
        'id': 3,
        'sender_ids': ['HDFCBK'],
        'pattern': r'Paid Rs (?<amount>[\d,.]+) to (?<payee>.+)',
      });
      final outcome = MessageParser([noDate]).parse(sms('Paid Rs 20 to CHAI WALA', at: DateTime(2026, 9, 5, 23, 10)));
      expect((outcome as ParsedDebit).payment.occurredOn, DateTime(2026, 9, 5));
    });

    test('an impossible or distant date falls back too', () {
      final a = parser.parse(sms(debit('10', date: '31/02/26'))) as ParsedDebit;
      expect(a.payment.occurredOn, DateTime(2026, 8, 2));
      final b = parser.parse(sms(debit('10', date: '02/08/21'))) as ParsedDebit;
      expect(b.payment.occurredOn, DateTime(2026, 8, 2));
    });

    test('a payment just before midnight keeps the bank date', () {
      final outcome = parser.parse(sms(debit('10', date: '01/08/26'), at: DateTime(2026, 8, 2, 0, 1))) as ParsedDebit;
      expect(outcome.payment.occurredOn, DateTime(2026, 8, 1));
    });

    test('supported formats', () {
      expect(parseTemplateDate('02/08/26', 'dd/MM/yy'), DateTime(2026, 8, 2));
      expect(parseTemplateDate('02-08-2026', 'dd-MM-yyyy'), DateTime(2026, 8, 2));
      expect(parseTemplateDate('2-Aug-26', 'd-MMM-yy'), DateTime(2026, 8, 2));
      expect(parseTemplateDate('02AUG2026', 'ddMMMyyyy'), DateTime(2026, 8, 2));
      expect(parseTemplateDate('2026-08-02', 'yyyy-MM-dd'), DateTime(2026, 8, 2));
      expect(parseTemplateDate('02/08', 'dd/MM/yy'), isNull);
      expect(parseTemplateDate('aa/bb/cc', 'dd/MM/yy'), isNull);
      expect(parseTemplateDate('02/08/26', ''), isNull);
    });
  });

  group('client transaction id', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1785678600123);

    test('is deterministic and a UUIDv5', () {
      final a = clientTxnId(sender: 'AD-HDFCBK', receivedAt: at, body: sample);
      final b = clientTxnId(sender: 'AD-HDFCBK', receivedAt: at, body: sample);
      expect(a, b);
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(a), isTrue);
    });

    test('changes with sender, time or text', () {
      final base = clientTxnId(sender: 'AD-HDFCBK', receivedAt: at, body: sample);
      expect(clientTxnId(sender: 'VM-HDFCBK', receivedAt: at, body: sample), isNot(base));
      expect(clientTxnId(sender: 'AD-HDFCBK', receivedAt: at.add(const Duration(milliseconds: 1)), body: sample),
          isNot(base));
      expect(clientTxnId(sender: 'AD-HDFCBK', receivedAt: at, body: '$sample.'), isNot(base));
    });

    test('parsing the same message twice gives the same id', () {
      final a = parser.parse(sms(sample)) as ParsedDebit;
      final b = parser.parse(sms(sample)) as ParsedDebit;
      expect(a.payment.clientTxnId, b.payment.clientTxnId);
    });
  });

  group('templates', () {
    test('lower priority number is tried first', () {
      final greedy = ParserTemplate.fromJson({
        'id': 9,
        'bank': 'GREEDY',
        'sender_ids': ['HDFCBK'],
        'pattern': r'Rs\.(?<amount>[\d,.]+).*To (?<payee>\w+)',
        'flags': 's',
        'priority': 50,
      });
      final outcome = MessageParser([greedy, hdfcDebit]).parse(sms(sample)) as ParsedDebit;
      expect(outcome.payment.bank, 'HDFC');
    });

    test('flags map to dotAll and caseInsensitive', () {
      final t = ParserTemplate.fromJson({
        'id': 4,
        'sender_ids': ['HDFCBK'],
        'pattern': r'sent rs\.(?<amount>\d+).to (?<payee>\w+)',
        'flags': 'si',
      });
      expect(MessageParser([t]).parse(sms('Sent Rs.40\nTo BOB')), isA<ParsedDebit>());
      final strict = ParserTemplate.fromJson({...t.toJson(), 'flags': ''});
      expect(MessageParser([strict]).parse(sms('Sent Rs.40\nTo BOB')), isA<Unparsed>());
    });

    test('a template whose pattern does not compile is skipped', () {
      final broken = ParserTemplate.fromJson({
        'id': 5,
        'sender_ids': ['HDFCBK'],
        'pattern': r'Sent (?<amount>\d+',
        'priority': 1,
      });
      expect(MessageParser([broken, hdfcDebit]).parse(sms(sample)), isA<ParsedDebit>());
    });

    test('sender codes are collected for the native filter', () {
      expect(parser.senderCodes, {'HDFCBK'});
    });

    test('json round trip', () {
      final again = ParserTemplate.fromJson(hdfcDebit.toJson());
      expect(again.pattern, hdfcDebit.pattern);
      expect(again.senderIds, ['HDFCBK']);
      expect(again.dateFormat, 'dd/MM/yy');
    });
  });

  group('sender matcher mirrors the Kotlin filter', () {
    const allowed = ['HDFCBK', 'SBIUPI'];
    test('accepts', () {
      expect(matchSenderCode('HDFCBK', allowed), 'HDFCBK');
      expect(matchSenderCode('AD-HDFCBK', allowed), 'HDFCBK');
      expect(matchSenderCode('VM-HDFCBK-S', allowed), 'HDFCBK');
      expect(matchSenderCode('HDFCBK-S', allowed), 'HDFCBK');
      expect(matchSenderCode(' ad-hdfcbk ', allowed), 'HDFCBK');
      expect(matchSenderCode('ADHDFCBK', allowed), 'HDFCBK');
    });
    test('rejects', () {
      for (final s in [
        'AD-HDFCBKX', 'AD-XHDFCBK', 'AD-MYHDFCBK-S', 'HDFCBK-OFFERS', 'AD-HDFCBK-S-X', '12HDFCBK',
        'AD-ICICIB', '+919876543210', 'AD', '',
      ]) {
        expect(matchSenderCode(s, allowed), isNull, reason: s);
      }
      expect(matchSenderCode(null, allowed), isNull);
      expect(matchSenderCode('AD-HDFCBK', const []), isNull);
      expect(matchSenderCode('AD-HDFCBK', const ['AD']), isNull);
    });
  });
}
