import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/api/api_exception.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../data/secret_store.dart';
import '../consent/notices.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class SessionState {
  const SessionState({
    this.status = AuthStatus.unknown,
    this.consents = const ConsentState.none(),
    this.onboardingDone = false,
    this.phone = '',
  });

  final AuthStatus status;

  /// The server is the source of truth; this is its last known answer.
  final ConsentState consents;
  final bool onboardingDone;
  final String phone;

  bool get signedIn => status == AuthStatus.signedIn;
  bool get mayCapture => signedIn && consents.has(Purpose.privateAnalytics);

  SessionState copyWith({AuthStatus? status, ConsentState? consents, bool? onboardingDone, String? phone}) =>
      SessionState(
        status: status ?? this.status,
        consents: consents ?? this.consents,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        phone: phone ?? this.phone,
      );
}

/// Who is signed in, what they consented to, and the data effects of both.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.watch(signOutSignalProvider).listener = _onSessionEnded;
    return const SessionState();
  }

  LocalStore get _store => ref.read(localStoreProvider);

  /// Called once at start-up.
  Future<void> bootstrap() async {
    final tokens = await ref.read(tokenStoreProvider).load();
    if (tokens == null) {
      state = const SessionState(status: AuthStatus.signedOut);
      return;
    }
    state = SessionState(
      status: AuthStatus.signedIn,
      consents: ConsentState.decode(await _store.getSetting(SettingKeys.consents)),
      onboardingDone: await _store.getSetting(SettingKeys.onboardingDone) == '1',
      phone: await _store.getSetting(SettingKeys.userPhone) ?? '',
    );
    // Do not block the first frame on the network. Consents are reloaded by the
    // app coordinator right after start-up and on every resume.
    ref.read(templateSyncProvider).sync().ignore();
  }

  /// After a successful OTP verification (tokens are already stored).
  Future<void> onSignedIn(AuthSession session) async {
    await _store.setSetting(SettingKeys.userPhone, session.user.phone);
    state = SessionState(status: AuthStatus.signedIn, phone: session.user.phone);
    await _registerDevice();
    await ref.read(templateSyncProvider).sync();
    await refreshConsents();
  }

  Future<void> _registerDevice() async {
    try {
      final installId = await InstallIdStore(ref.read(secretStoreProvider)).id();
      await ref.read(accountApiProvider).registerDevice(
            deviceId: installId,
            appVersion: await ref.read(appVersionProvider.future),
          );
    } on ApiException {
      // Not essential; it is sent again on the next sign-in.
    }
  }

  /// Loads the consent state from the server and applies its effects. Keeps the
  /// cached state when the server cannot be reached.
  Future<ConsentState> refreshConsents() async {
    if (!state.signedIn) return state.consents;
    try {
      final consents = await ref.read(consentApiProvider).current();
      await _apply(consents);
    } on ApiException {
      await _applyCaptureSwitch(state.consents);
    }
    return state.consents;
  }

  /// Grants or withdraws one purpose on the server, then applies the new state.
  /// Throws [ApiException] (code "dependency" when the parent consent is missing).
  Future<void> setConsent(Purpose purpose, bool granted) async {
    final consents = await ref.read(consentApiProvider).set(purpose, granted: granted, noticeVersion: noticeVersion);
    await _apply(consents);
  }

  Future<void> _apply(ConsentState consents) async {
    final hadCapture = state.consents.has(Purpose.privateAnalytics);
    await _store.setSetting(SettingKeys.consents, consents.encode());
    state = state.copyWith(consents: consents);
    await _applyCaptureSwitch(consents);
    if (!consents.has(Purpose.privateAnalytics) && (hadCapture || await _hasCapturedData())) {
      // Withdrawn (here or on another device): the server deleted the payments;
      // remove the local copies and anything still queued.
      await ref.read(captureControlProvider).clearQueue();
      await _store.wipeCaptured();
      await ref.read(promptNotifierProvider).cancelAll();
    }
  }

  Future<bool> _hasCapturedData() async =>
      await _store.pendingCount() > 0 || (await _store.watchAll().first).isNotEmpty || await _store.unparsedCount() > 0;

  /// Capture runs only while the private-analytics consent is held.
  Future<void> _applyCaptureSwitch(ConsentState consents) async {
    final control = ref.read(captureControlProvider);
    final enabled = consents.has(Purpose.privateAnalytics);
    await control.setCaptureEnabled(enabled);
    if (enabled) await control.registerBackgroundEntryPoint();
  }

  Future<void> completeOnboarding() async {
    await _store.setSetting(SettingKeys.onboardingDone, '1');
    state = state.copyWith(onboardingDone: true);
  }

  /// Sign out: this device forgets everything. Server data is untouched.
  Future<void> signOut() async {
    await _wipeDevice();
    state = const SessionState(status: AuthStatus.signedOut);
  }

  /// Deletes the account and all its data on the server, then wipes this device.
  Future<void> deleteAccount() async {
    await ref.read(accountApiProvider).deleteAccount();
    await signOut();
  }

  /// The refresh token was rejected: the tokens are already gone.
  Future<void> _onSessionEnded() async {
    if (state.status == AuthStatus.signedOut) return;
    await _wipeDevice();
    state = const SessionState(status: AuthStatus.signedOut);
  }

  Future<void> _wipeDevice() async {
    final control = ref.read(captureControlProvider);
    await control.setCaptureEnabled(false);
    await control.setAllowedSenders(const {});
    await control.clearQueue();
    await ref.read(promptNotifierProvider).cancelAll();
    await _store.wipeAll();
    await ref.read(tokenStoreProvider).clear();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// "0.1.0", sent when the device is registered. Overridden with the real value at start-up.
final appVersionProvider = FutureProvider<String>((ref) async => '0.0.0');
