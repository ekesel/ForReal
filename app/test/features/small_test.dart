import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/features/auth/otp_screen.dart';
import 'package:forreal/features/auth/phone_screen.dart';
import 'package:forreal/features/location/location_service.dart';
import 'package:forreal/features/parser_gaps/parser_gaps_screen.dart';

void main() {
  group('parser gaps masking', () {
    test('every digit is masked, everything else is kept', () {
      expect(
        maskDigits('Rs.1,250.50 debited from A/C *1234 on 02/08/26. Ref 400012345678. Call 18002586161'),
        'Rs.X,XXX.XX debited from A/C *XXXX on XX/XX/XX. Ref XXXXXXXXXXXX. Call XXXXXXXXXXX',
      );
      expect(maskDigits('123456 is your OTP'), 'XXXXXX is your OTP');
      expect(maskDigits('no digits'), 'no digits');
    });

    test('the copied report is masked too', () {
      final message = UnparsedMessage(
        id: 1,
        sender: 'AD-HDFCBK',
        receivedAt: DateTime(2026, 8, 2),
        body: 'Your a/c XX1234 debited INR 500.00',
      );
      final report = gapReport(message);
      expect(report, 'Sender: AD-HDFCBK\nYour a/c XXXXXX debited INR XXX.XX');
      expect(RegExp(r'\d').hasMatch(report), isFalse);
    });
  });

  group('sign-in messages', () {
    test('asking for a code', () {
      expect(
        otpRequestError(const ApiException(statusCode: 429, code: 'too_many_requests', message: 'x')),
        contains('Too many codes'),
      );
      expect(otpRequestError(const ApiException(statusCode: 429, message: 'Request was throttled.')), contains('wait'));
      expect(
        otpRequestError(const ApiException(statusCode: 400, message: 'bad', fieldErrors: {'phone': 'Phone must be...'})),
        'Enter a valid mobile number.',
      );
      expect(otpRequestError(const ApiException(message: 'No connection')), 'No connection');
    });

    test('checking a code', () {
      String text(String code, [int status = 400]) =>
          otpVerifyError(ApiException(statusCode: status, code: code, message: 'server text'));
      expect(text('invalid'), contains('not right'));
      expect(text('expired'), contains('expired'));
      expect(text('too_many_attempts'), contains('Too many wrong attempts'));
      expect(text('inactive', 403), contains('disabled'));
      expect(otpVerifyError(const ApiException(statusCode: 429, message: 'throttled')), contains('wait'));
      expect(otpVerifyError(const ApiException(statusCode: 500, message: 'server text')), 'server text');
    });
  });

  test('"where I am now" only counts for ten minutes after a payment', () {
    final now = DateTime(2026, 8, 2, 18, 30);
    expect(withinLocationWindow(now.subtract(const Duration(minutes: 9, seconds: 59)), now), isTrue);
    expect(withinLocationWindow(now.subtract(const Duration(minutes: 10)), now), isFalse);
    expect(withinLocationWindow(now.add(const Duration(minutes: 1)), now), isFalse);
  });
}
