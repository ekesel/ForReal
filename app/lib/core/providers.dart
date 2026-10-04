import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/background_runner.dart';
import '../capture/capture_pipeline.dart';
import '../capture/template_sync.dart';
import '../capture/transaction_source.dart';
import '../data/api/api_client.dart';
import '../data/api/repositories.dart';
import '../data/db/database.dart';
import '../data/db/open_database.dart';
import '../data/local_store.dart';
import '../data/secret_store.dart';
import '../features/items/items_service.dart';
import '../features/location/location_service.dart';
import '../features/notifications/notification_answers.dart';
import '../features/notifications/prompts.dart';
import '../features/payee/payee_service.dart';
import '../features/sync/sync_service.dart';
import 'config.dart';

/// The object graph. Platform pieces (keystore, SMS source, location, notifications)
/// are overridden in lib/bootstrap.dart; everything else is plain Dart.

Never _unbound(String name) => throw UnimplementedError('$name must be overridden at start-up.');

final secretStoreProvider = Provider<SecretStore>((ref) => _unbound('secretStoreProvider'));
final transactionSourceProvider = Provider<TransactionSource>((ref) => _unbound('transactionSourceProvider'));
final captureControlProvider = Provider<CaptureControl>((ref) => _unbound('captureControlProvider'));

/// No location unless the UI isolate provides one: background code must never use it.
final locationServiceProvider = Provider<LocationService>((ref) => const NoLocation());
final promptNotifierProvider = Provider<PromptNotifier>((ref) => const SilentNotifier());
final notificationPermissionsProvider =
    Provider<NotificationPermissions>((ref) => const NoNotificationPermissions());

/// "Now" for anything the screens show relative to today. Fixed in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Opens this app's page in the system settings (permissions). Bound at start-up.
final openAppSettingsProvider = Provider<Future<void> Function()>((ref) => () async {});

/// Lets the API client report "the session ended" without knowing who listens.
class SignOutSignal {
  Future<void> Function()? listener;
  Future<void> fire() async => listener?.call();
}

final signOutSignalProvider = Provider<SignOutSignal>((ref) => SignOutSignal());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(secretStoreProvider)));

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase(DatabaseKeyStore(ref.watch(secretStoreProvider)));
  ref.onDispose(db.close);
  return db;
});

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(databaseProvider)));

final apiClientProvider = Provider<ApiClient>((ref) {
  final signal = ref.watch(signOutSignalProvider);
  return ApiClient(
    baseUrl: AppConfig.apiRoot,
    tokens: ref.watch(tokenStoreProvider),
    onSignedOut: signal.fire,
  );
});

final authApiProvider = Provider((ref) => AuthApi(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
final accountApiProvider = Provider((ref) => AccountApi(ref.watch(apiClientProvider)));
final consentApiProvider = Provider((ref) => ConsentApi(ref.watch(apiClientProvider)));
final templatesApiProvider = Provider((ref) => TemplatesApi(ref.watch(apiClientProvider)));
final transactionsApiProvider = Provider((ref) => TransactionsApi(ref.watch(apiClientProvider)));
final merchantsApiProvider = Provider((ref) => MerchantsApi(ref.watch(apiClientProvider)));
final taggingApiProvider = Provider((ref) => TaggingApi(ref.watch(apiClientProvider)));

final templateSyncProvider = Provider((ref) => TemplateSync(
      api: ref.watch(templatesApiProvider),
      store: ref.watch(localStoreProvider),
      control: ref.watch(captureControlProvider),
    ));

final capturePipelineProvider = Provider((ref) => CapturePipeline(
      source: ref.watch(transactionSourceProvider),
      store: ref.watch(localStoreProvider),
      templates: ref.watch(templateSyncProvider),
    ));

final syncServiceProvider = Provider((ref) => SyncService(
      store: ref.watch(localStoreProvider),
      transactions: ref.watch(transactionsApiProvider),
      merchants: ref.watch(merchantsApiProvider),
      tagging: ref.watch(taggingApiProvider),
      location: ref.watch(locationServiceProvider),
    ));

final promptServiceProvider = Provider((ref) => PromptService(
      store: ref.watch(localStoreProvider),
      notifier: ref.watch(promptNotifierProvider),
    ));

final payeeServiceProvider = Provider((ref) => PayeeService(
      store: ref.watch(localStoreProvider),
      merchants: ref.watch(merchantsApiProvider),
      transactions: ref.watch(transactionsApiProvider),
      location: ref.watch(locationServiceProvider),
      notifier: ref.watch(promptNotifierProvider),
    ));

final itemsServiceProvider = Provider((ref) => ItemsService(
      store: ref.watch(localStoreProvider),
      tagging: ref.watch(taggingApiProvider),
      notifier: ref.watch(promptNotifierProvider),
    ));

final notificationAnswersProvider = Provider((ref) => NotificationAnswers(
      store: ref.watch(localStoreProvider),
      payees: ref.watch(payeeServiceProvider),
      items: ref.watch(itemsServiceProvider),
    ));

final backgroundRunnerProvider = Provider((ref) => BackgroundRunner(
      tokens: ref.watch(tokenStoreProvider),
      store: ref.watch(localStoreProvider),
      templates: ref.watch(templateSyncProvider),
      pipeline: ref.watch(capturePipelineProvider),
      sync: ref.watch(syncServiceProvider),
      prompts: ref.watch(promptServiceProvider),
    ));
