import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/api/api_exception.dart';
import '../session/session_controller.dart';
import 'phone_screen.dart';

class OtpArgs {
  const OtpArgs({required this.phone, this.debugCode});
  final String phone;

  /// Only sent by a development backend (OTP_ECHO_IN_RESPONSE).
  final String? debugCode;
}

/// What to tell the user when the code is not accepted. Codes come from
/// backend/apps/accounts/otp.py and views.py.
String otpVerifyError(ApiException e) => switch (e.code) {
      'invalid' => 'That code is not right. Check it and try again.',
      'expired' => 'That code has expired. Ask for a new one.',
      'too_many_attempts' => 'Too many wrong attempts. Ask for a new code.',
      'inactive' => 'This account has been disabled.',
      _ => e.isRateLimited ? 'Too many attempts. Please wait a few minutes and try again.' : e.message,
    };

/// "+91 98765 43210"
String spacedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return phone;
  final local = digits.substring(digits.length - 10);
  final country = digits.substring(0, digits.length - 10);
  return '${country.isEmpty ? '' : '+$country '}${local.substring(0, 5)} ${local.substring(5)}';
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendAfter = 30;

  late final TextEditingController _code;
  final _focus = FocusNode();
  String? _error;
  Timer? _timer;
  int _secondsLeft = _resendAfter;

  @override
  void initState() {
    super.initState();
    // Debug builds only: prefill the code a development backend echoes back.
    _code = TextEditingController(text: kDebugMode ? widget.args.debugCode ?? '' : '');
    _code.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() => _error = null);
    try {
      final session = await ref.read(authApiProvider).verifyOtp(widget.args.phone, code);
      // The router moves on as soon as the session says "signed in".
      await ref.read(sessionProvider.notifier).onSignedIn(session);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = otpVerifyError(e));
    }
  }

  Future<void> _resend() async {
    try {
      final result = await ref.read(authApiProvider).requestOtp(widget.args.phone);
      if (!mounted) return;
      if (kDebugMode && result.debugCode != null) _code.text = result.debugCode!;
      setState(() => _error = null);
      _startCountdown();
      showMessage(context, 'A new code is on its way.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = otpRequestError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.args.phone.isEmpty) {
      // Opened without a number (for example after a restart): start again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/sign-in');
      });
    }
    final seconds = _secondsLeft.clamp(0, _resendAfter);
    return Scaffold(
      body: ScreenBody(
        gap: AppSpace.x24,
        actions: [AppButton(label: 'Verify', onPressed: _verify)],
        children: [
          ScreenHeader(onBack: () => context.go('/sign-in')),
          TitleBlock(title: 'Enter the code', subtitle: 'Sent to ${spacedPhone(widget.args.phone)}'),
          _CodeBoxes(controller: _code, focusNode: _focus, onSubmitted: _verify),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: AppText.labelM.copyWith(color: c.danger)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: seconds > 0
                ? Text(
                    'Resend code in 0:${seconds.toString().padLeft(2, '0')}',
                    style: AppText.labelM.copyWith(color: c.inkMuted),
                  )
                : InkWell(
                    onTap: _resend,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: AppSize.touch),
                      child: Align(
                        widthFactor: 1,
                        alignment: Alignment.centerLeft,
                        child: Text('Send a new code', style: AppText.labelM.copyWith(color: c.ink)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Six boxes drawn over one real text field, so paste, autofill and the keyboard
/// all behave as usual.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.focusNode, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = controller.text;
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.x8),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.r14),
                        border: focusNode.hasFocus && i == text.length.clamp(0, 5)
                            ? Border.all(color: c.ink, width: AppSize.lineStrong)
                            : Border.all(color: c.line),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        textScaler: TextScaler.noScaling,
                        style: AppText.displayM.copyWith(color: c.ink),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // The real field: invisible text, same size as the boxes.
          Positioned.fill(
            child: Semantics(
              label: '6-digit code',
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                showCursor: false,
                enableInteractiveSelection: false,
                style: AppText.displayM.copyWith(color: c.surface.withValues(alpha: 0)),
                decoration: const InputDecoration(
                  filled: false,
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
