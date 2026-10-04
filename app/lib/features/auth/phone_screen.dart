import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/api/api_exception.dart';
import 'otp_screen.dart';

/// The backend is in closed testing and this number is not on its list.
const notInvitedMessage = 'This number isn’t on the test list. Ask the ForReal team to add it.';

/// What to tell the user when asking for a code fails.
String otpRequestError(ApiException e) {
  if (e.code == 'not_invited') return notInvitedMessage;
  if (e.fieldErrors['phone'] != null) return 'Enter a valid mobile number.';
  if (e.isRateLimited) {
    return e.code == 'too_many_requests'
        ? 'Too many codes requested for this number. Try again in an hour.'
        : 'Too many attempts. Please wait a few minutes and try again.';
  }
  return e.message;
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    setState(() => _error = null);
    final phone = '+91$digits';
    try {
      final result = await ref.read(authApiProvider).requestOtp(phone);
      if (!mounted) return;
      context.go('/sign-in/otp', extra: OtpArgs(phone: phone, debugCode: result.debugCode));
    } on ApiException catch (e) {
      setState(() => _error = otpRequestError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBody(
        gap: AppSpace.x24,
        actions: [AppButton(label: 'Send code', onPressed: _send)],
        children: [
          ScreenHeader(onBack: () => context.go('/welcome')),
          const TitleBlock(
            title: 'What’s your number?',
            subtitle: 'We’ll text you a 6-digit code. No passwords.',
          ),
          AppTextField(
            controller: _phone,
            prefix: '+91',
            hint: '98765 43210',
            errorText: _error,
            autofocus: true,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: AppText.titleM,
            onSubmitted: (_) => _send(),
          ),
        ],
      ),
    );
  }
}
