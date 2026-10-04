import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/router.dart';
import 'package:forreal/data/api/api_exception.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/consent/notices.dart';
import 'package:forreal/features/session/session_controller.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';
import '../support/harness.dart';

AuthSession newSession() => AuthSession.fromJson({
      'access': 'access-1',
      'refresh': 'refresh-1',
      'is_new_user': true,
      'user': {'id': 'u-1', 'phone': '+919876543210', 'display_name': ''},
    });

void main() {
  late Harness h;

  setUp(() {
    h = Harness();
    h.serveConsents();
    h.serveTemplates();
    h.api.reply('PUT', 'me/device/', {'device_id': 'x'});
  });
  tearDown(() => h.dispose());

  Future<void> signIn({bool privateAnalytics = false}) async {
    h.serverConsents['private_analytics'] = privateAnalytics;
    await h.session.onSignedIn(newSession());
  }

  Future<void> capturePayment(String id) async {
    await h.store.insertParsed(parsed(id), fromHistory: false);
    await h.store.applyIngestResult(id, IngestResult.fromJson(ingestResult(serverTxn(id))));
  }

  group('start-up', () {
    test('without tokens the user is signed out', () async {
      h.dispose();
      h = Harness(signedIn: false);
      await h.session.bootstrap();
      expect(h.state.status, AuthStatus.signedOut);
    });

    test('with tokens the cached consents and onboarding flag are restored', () async {
      await h.store.setSetting(SettingKeys.consents, const ConsentState({'private_analytics': true}).encode());
      await h.store.setSetting(SettingKeys.onboardingDone, '1');
      await h.store.setSetting(SettingKeys.userPhone, '+919876543210');
      await h.session.bootstrap();
      expect(h.state.signedIn, isTrue);
      expect(h.state.mayCapture, isTrue);
      expect(h.state.onboardingDone, isTrue);
      expect(h.state.phone, '+919876543210');
    });
  });

  group('sign-in', () {
    test('registers the device, downloads templates and loads consents from the server', () async {
      await signIn();

      final device = h.api.to('PUT', 'me/device/').single.json;
      expect(device['platform'], 'android');
      expect(device['app_version'], '9.9.9');
      expect(device['push_token'], '');
      expect((device['device_id'] as String).length, greaterThan(20));
      expect(h.source.allowedSenders, {'HDFCBK'});
      expect(h.state.signedIn, isTrue);
      expect(h.state.consents.has(Purpose.privateAnalytics), isFalse);
      expect(h.state.phone, '+919876543210');
    });

    test('the install id is stable across sign-ins', () async {
      await signIn();
      await h.session.onSignedIn(newSession());
      final ids = [for (final r in h.api.to('PUT', 'me/device/')) r.json['device_id']];
      expect(ids.first, ids.last);
    });

    test('nothing is captured before the private-analytics consent', () async {
      await signIn();
      expect(h.source.captureEnabled, isFalse);
      expect(h.source.backgroundRegistrations, 0);
    });

    test('a returning user who already consented gets capture switched on', () async {
      await signIn(privateAnalytics: true);
      expect(h.source.captureEnabled, isTrue);
      expect(h.source.backgroundRegistrations, 1);
    });
  });

  group('consent', () {
    test('granting goes through the server with the notice version and switches capture on', () async {
      await signIn();
      await h.session.setConsent(Purpose.privateAnalytics, true);

      expect(h.api.to('POST', 'consents/').single.json,
          {'purpose': 'private_analytics', 'granted': true, 'notice_version': noticeVersion});
      expect(noticeVersion.length, lessThanOrEqualTo(20), reason: 'backend field limit');
      expect(h.state.mayCapture, isTrue);
      expect(h.source.captureEnabled, isTrue);
      expect(h.source.backgroundRegistrations, 1);
      expect(ConsentState.decode(await h.store.getSetting(SettingKeys.consents)).has(Purpose.privateAnalytics), isTrue);
    });

    test('withdrawing private analytics stops capture and wipes local payment data', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.source.enqueue('AD-HDFCBK', hdfcSms());
      await h.store.saveTemplates(5, [hdfcTemplate]);

      await h.session.setConsent(Purpose.privateAnalytics, false);

      expect(h.source.captureEnabled, isFalse);
      expect(h.source.queueCleared, isTrue);
      expect(await h.store.get('a'), isNull);
      expect(h.notifier.cancelledAll, isTrue);
      expect(h.state.mayCapture, isFalse);
      expect(await h.store.loadTemplates(), hasLength(1), reason: 'templates are not personal data');
    });

    test('a withdrawal made on another device is applied on the next load', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.serverConsents['private_analytics'] = false;

      await h.session.refreshConsents();

      expect(h.source.captureEnabled, isFalse);
      expect(await h.store.get('a'), isNull);
    });

    test('when the server cannot be reached the cached state stays and nothing is wiped', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.api.on('GET', 'consents/', (_) => throw const Offline());

      await h.session.refreshConsents();

      expect(h.state.mayCapture, isTrue);
      expect(h.source.captureEnabled, isTrue);
      expect(await h.store.get('a'), isNotNull);
    });

    test('other consents do not touch capture or local data', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      await h.session.setConsent(Purpose.location, true);
      await h.session.setConsent(Purpose.location, false);
      expect(h.source.captureEnabled, isTrue);
      expect(await h.store.get('a'), isNotNull);
      expect(h.state.consents.has(Purpose.location), isFalse);
    });

    test('a dependency error from the server reaches the caller', () async {
      await signIn();
      h.api.reply('POST', 'consents/',
          {'code': 'dependency', 'detail': "'show_name' needs 'community_rankings' to be granted first."},
          status: 400);
      await expectLater(
        h.session.setConsent(Purpose.showName, true),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'dependency')),
      );
      expect(h.state.consents.has(Purpose.showName), isFalse);
    });

    test('dependency rules match the backend', () {
      expect(Purpose.privateAnalytics.requires, isNull);
      expect(Purpose.communityRankings.requires, Purpose.privateAnalytics);
      expect(Purpose.location.requires, Purpose.privateAnalytics);
      expect(Purpose.showName.requires, Purpose.communityRankings);
      expect(Purpose.merchantInsights.requires, Purpose.communityRankings);
    });
  });

  group('leaving', () {
    Future<void> expectDeviceWiped() async {
      expect(h.state.status, AuthStatus.signedOut);
      expect(await h.backend.tokens.load(), isNull);
      expect(await h.store.get('a'), isNull);
      expect(await h.store.loadTemplates(), isEmpty);
      expect(await h.store.getSetting(SettingKeys.consents), isNull);
      expect(h.source.captureEnabled, isFalse);
      expect(h.source.allowedSenders, isEmpty);
      expect(h.source.queueCleared, isTrue);
      expect(h.notifier.cancelledAll, isTrue);
    }

    test('sign out wipes the local database and the tokens', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      await h.session.signOut();
      await expectDeviceWiped();
      expect(h.api.to('DELETE', 'me/'), isEmpty);
    });

    test('delete account deletes on the server, then wipes the device', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.api.reply('DELETE', 'me/', null, status: 204);
      await h.session.deleteAccount();
      expect(h.api.to('DELETE', 'me/'), hasLength(1));
      await expectDeviceWiped();
    });

    test('if the server refuses the deletion, nothing is wiped', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.api.on('DELETE', 'me/', (_) => throw const Offline());
      await expectLater(h.session.deleteAccount(), throwsA(isA<ApiException>()));
      expect(h.state.signedIn, isTrue);
      expect(await h.store.get('a'), isNotNull);
    });

    test('a rejected refresh token signs out and wipes the device', () async {
      await signIn(privateAnalytics: true);
      await capturePayment('a');
      h.api.reply('GET', 'consents/', {'code': 'token_not_valid'}, status: 401);
      h.api.reply('POST', 'auth/token/refresh/', {'code': 'token_not_valid'}, status: 401);

      await h.session.refreshConsents();

      await expectDeviceWiped();
    });
  });

  group('route guard', () {
    const consented = ConsentState({'private_analytics': true});

    test('before the session is known everything waits on the splash', () {
      expect(routeGuard(const SessionState(), '/'), '/splash');
      expect(routeGuard(const SessionState(), '/splash'), isNull);
    });

    test('signed out users only see welcome and sign-in', () {
      const s = SessionState(status: AuthStatus.signedOut);
      // The new welcome screen is the front door; sign-in follows from it.
      expect(routeGuard(s, '/'), '/welcome');
      expect(routeGuard(s, '/txn/abc'), '/welcome');
      expect(routeGuard(s, '/settings'), '/welcome');
      expect(routeGuard(s, '/discover'), '/welcome');
      expect(routeGuard(s, '/welcome'), isNull);
      expect(routeGuard(s, '/sign-in'), isNull);
      expect(routeGuard(s, '/sign-in/otp'), isNull);
    });

    test('without the required consent only onboarding is reachable', () {
      const s = SessionState(status: AuthStatus.signedIn, onboardingDone: true);
      expect(routeGuard(s, '/'), '/onboarding');
      expect(routeGuard(s, '/txn/abc/items'), '/onboarding');
      expect(routeGuard(s, '/onboarding'), isNull);
    });

    test('onboarding must be finished even with the consent', () {
      const s = SessionState(status: AuthStatus.signedIn, consents: consented);
      expect(routeGuard(s, '/'), '/onboarding');
    });

    test('a fully set up user goes to the app and leaves sign-in and onboarding', () {
      const s = SessionState(status: AuthStatus.signedIn, consents: consented, onboardingDone: true);
      expect(routeGuard(s, '/'), isNull);
      expect(routeGuard(s, '/txn/abc/payee'), isNull);
      expect(routeGuard(s, '/discover'), isNull);
      expect(routeGuard(s, '/insights'), isNull);
      expect(routeGuard(s, '/welcome'), '/');
      expect(routeGuard(s, '/sign-in/otp'), '/');
      expect(routeGuard(s, '/onboarding'), '/');
      expect(routeGuard(s, '/splash'), '/');
    });
  });
}
