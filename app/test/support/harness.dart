import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forreal/core/providers.dart';
import 'package:forreal/data/db/database.dart';
import 'package:forreal/data/local_store.dart';
import 'package:forreal/features/location/location_service.dart';
import 'package:forreal/features/session/session_controller.dart';

import 'fake_api.dart';
import 'fakes.dart';

/// The real provider graph with fakes at the edges: HTTP, keystore, SMS source,
/// notifications, location, and an in-memory database.
class Harness {
  Harness({bool signedIn = true, LocationService? location}) : backend = TestBackend(signedIn: signedIn) {
    // Each test (and sometimes two harnesses in one test) opens its own in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      secretStoreProvider.overrideWithValue(backend.secrets),
      apiClientProvider.overrideWith((ref) {
        backend.client.onSignedOut = ref.watch(signOutSignalProvider).fire;
        return backend.client;
      }),
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      transactionSourceProvider.overrideWithValue(source),
      captureControlProvider.overrideWithValue(source),
      promptNotifierProvider.overrideWithValue(notifier),
      if (location != null) locationServiceProvider.overrideWithValue(location),
      appVersionProvider.overrideWith((ref) async => '9.9.9'),
    ]);
  }

  final TestBackend backend;
  final FakeSource source = FakeSource();
  final RecordingNotifier notifier = RecordingNotifier();
  late final ProviderContainer container;

  FakeApi get api => backend.api;
  LocalStore get store => container.read(localStoreProvider);
  SessionController get session => container.read(sessionProvider.notifier);
  SessionState get state => container.read(sessionProvider);

  /// Server-side consent state, served by GET consents/ and changed by POST consents/.
  final Map<String, bool> serverConsents = {
    'private_analytics': false,
    'community_rankings': false,
    'show_name': false,
    'location': false,
    'merchant_insights': false,
  };

  void serveConsents() {
    api.on('GET', 'consents/', (_) => FakeResponse.ok({'consents': Map.of(serverConsents)}));
    api.on('POST', 'consents/', (r) {
      serverConsents[r.json['purpose'] as String] = r.json['granted'] as bool;
      return FakeResponse.ok({'consents': Map.of(serverConsents)});
    });
  }

  void serveTemplates() {
    api.reply('GET', 'parser-templates/', {'version': 5, 'changed': true, 'templates': [hdfcTemplate]});
  }

  void dispose() => container.dispose();
}
