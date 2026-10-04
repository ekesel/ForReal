import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'background.dart';
import 'capture/android_sms_source.dart';
import 'core/platform/secure_secret_store.dart';
import 'core/providers.dart';
import 'data/models.dart';
import 'features/app/app_coordinator.dart';
import 'features/location/geolocator_location.dart';
import 'features/notifications/local_notifications.dart';
import 'features/session/session_controller.dart';

/// Concrete platform pieces, exposed so start-up code can call their extra methods.
final androidSmsSourceProvider = Provider<AndroidSmsSource>((ref) => throw UnimplementedError());
final localNotificationsProvider = Provider<LocalNotifications>((ref) => throw UnimplementedError());

/// Binds the platform implementations. This is the only place (with main.dart and
/// background.dart) that knows the app runs on Android.
///
/// Background isolates get no location service at all: location is foreground-only.
List<Override> platformOverrides({required bool background}) {
  final sms = AndroidSmsSource(backgroundEntryPoint: captureBackgroundMain);
  final notifications = LocalNotifications(backgroundHandler: notificationBackgroundHandler);
  return [
    secretStoreProvider.overrideWithValue(const SecureSecretStore()),
    androidSmsSourceProvider.overrideWithValue(sms),
    transactionSourceProvider.overrideWithValue(sms),
    captureControlProvider.overrideWithValue(sms),
    localNotificationsProvider.overrideWithValue(notifications),
    promptNotifierProvider.overrideWithValue(notifications),
    notificationPermissionsProvider.overrideWithValue(notifications),
    openAppSettingsProvider.overrideWithValue(() async {
      await Geolocator.openAppSettings();
    }),
    appVersionProvider.overrideWith((ref) async => (await PackageInfo.fromPlatform()).version),
    if (!background) ...[
      locationServiceProvider.overrideWith(
        (ref) => GeolocatorLocation(
          consentGranted: () => ref.read(sessionProvider).consents.has(Purpose.location),
          inForeground: () => ref.read(appForegroundProvider).value,
        ),
      ),
      onlineChangesProvider.overrideWith(
        (ref) => Connectivity()
            .onConnectivityChanged
            .where((results) => results.any((r) => r != ConnectivityResult.none))
            .map<void>((_) {}),
      ),
    ],
  ];
}
