import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/isolate_ping.dart';
import 'core/providers.dart';
import 'features/notifications/local_notifications.dart';
import 'features/notifications/notification_answers.dart';

/// Entry points that run without the UI, each in its own isolate.

/// Run by the Kotlin CaptureWorker in a headless FlutterEngine after a bank message
/// was queued (or periodically): parse the queue, upload, notify.
@pragma('vm:entry-point')
Future<void> captureBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final container = ProviderContainer(overrides: platformOverrides(background: true));
  final sms = container.read(androidSmsSourceProvider);
  var retry = false;
  try {
    final reason = await sms.backgroundReason();
    retry = await container.read(backgroundRunnerProvider).run(reason: reason);
    notifyUiOfChanges();
  } catch (_) {
    retry = true;
  } finally {
    try {
      await container.read(databaseProvider).close();
    } catch (_) {
      // Closing is best effort; the engine is about to be destroyed.
    }
    // Last: the platform destroys this engine as soon as it hears "done".
    await sms.backgroundDone(retry: retry);
    container.dispose();
  }
}

/// Run by flutter_local_notifications when the user taps a notification button that
/// does not open the app: [Person], [Yes] or [Not a shop]. Works with the app killed.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  _answerFromNotification(response);
}

Future<void> _answerFromNotification(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final open = NotificationOpen.fromResponse(response);
  final id = open?.clientTxnId;
  if (open == null || id == null) return;
  final container = ProviderContainer(overrides: platformOverrides(background: true));
  try {
    await answerNotificationAction(container.read(notificationAnswersProvider), open.action, id);
    notifyUiOfChanges();
  } catch (_) {
    // Nothing useful can be shown from here; the payment stays untagged in the list.
  } finally {
    try {
      await container.read(databaseProvider).close();
    } catch (_) {}
    container.dispose();
  }
}
