import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/app/app_coordinator.dart';
import 'features/notifications/local_notifications.dart';
import 'features/notifications/notification_answers.dart';
import 'features/session/session_controller.dart';

class ForRealApp extends ConsumerStatefulWidget {
  const ForRealApp({super.key});

  @override
  ConsumerState<ForRealApp> createState() => _ForRealAppState();
}

class _ForRealAppState extends ConsumerState<ForRealApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final coordinator = ref.read(appCoordinatorProvider);
    _lifecycle = AppLifecycleListener(
      onResume: coordinator.onResume,
      onHide: coordinator.onPause,
      onPause: coordinator.onPause,
    );
    _start();
  }

  Future<void> _start() async {
    final notifications = ref.read(localNotificationsProvider);
    await notifications.initialize(onOpen: _open);
    await ref.read(sessionProvider.notifier).bootstrap();
    final coordinator = ref.read(appCoordinatorProvider)..start();
    final launch = await notifications.launchOpen();
    if (launch != null) _open(launch);
    await coordinator.onResume();
  }

  /// A notification (or one of its foreground buttons) was tapped.
  Future<void> _open(NotificationOpen open) async {
    final router = ref.read(routerProvider);
    if (!ref.read(sessionProvider).signedIn) return;
    final id = open.clientTxnId;
    if (open.type == 'summary' || id == null) {
      router.go('/?filter=untagged');
      return;
    }
    // Background buttons normally never reach the UI isolate, but answer them if they do.
    if (await answerNotificationAction(ref.read(notificationAnswersProvider), open.action, id)) return;
    switch (open.action) {
      case PromptActions.shop:
        router.go('/txn/$id/payee');
      case PromptActions.somethingElse:
        router.go('/txn/$id/items');
      default:
        router.go('/txn/$id');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ForReal',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      // Light or dark follows the phone's setting.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      // Follow the system text size, up to the largest size the layouts are built for.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: AppText.maxTextScale,
        child: child!,
      ),
    );
  }
}
