import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/home/coming_soon_screen.dart';
import '../features/home/home_screen.dart';
import '../features/items/items_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/parser_gaps/parser_gaps_screen.dart';
import '../features/payee/payee_screen.dart';
import '../features/session/session_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash_screen.dart';
import '../features/transaction/transaction_detail_screen.dart';

/// Where a session state is allowed to be. Null means "stay".
///
///  - not signed in: only the welcome and sign-in screens,
///  - signed in without the private-analytics consent, or before onboarding is
///    finished: only onboarding (this is also where a 403 from the server leads),
///  - otherwise: the app.
String? routeGuard(SessionState session, String location) {
  final onSignIn = location.startsWith('/sign-in') || location == '/welcome';
  switch (session.status) {
    case AuthStatus.unknown:
      return location == '/splash' ? null : '/splash';
    case AuthStatus.signedOut:
      return onSignIn ? null : '/welcome';
    case AuthStatus.signedIn:
      final needsOnboarding = !session.consents.has(Purpose.privateAnalytics) || !session.onboardingDone;
      if (needsOnboarding) return location == '/onboarding' ? null : '/onboarding';
      if (onSignIn || location == '/splash' || location == '/onboarding') return '/';
      return null;
  }
}

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => routeGuard(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      // Phase 4 tabs: present in the navigation, not built yet.
      GoRoute(path: '/discover', builder: (context, state) => const ComingSoonScreen.discover()),
      GoRoute(path: '/insights', builder: (context, state) => const ComingSoonScreen.insights()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const PhoneScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (context, state) {
              final args = state.extra is OtpArgs ? state.extra! as OtpArgs : const OtpArgs(phone: '');
              return OtpScreen(args: args);
            },
          ),
        ],
      ),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(untaggedOnly: state.uri.queryParameters['filter'] == 'untagged'),
        routes: [
          GoRoute(
            path: 'txn/:id',
            builder: (context, state) => TransactionDetailScreen(clientTxnId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'payee',
                builder: (context, state) => PayeeScreen(clientTxnId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'items',
                builder: (context, state) => ItemsScreen(clientTxnId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              // Debug builds only: how new bank formats get reported.
              if (kDebugMode) GoRoute(path: 'parser-gaps', builder: (context, state) => const ParserGapsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
