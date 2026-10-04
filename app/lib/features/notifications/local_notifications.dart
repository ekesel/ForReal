import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import 'prompts.dart';

/// What the user tapped: the notification body or one of its buttons.
class NotificationOpen {
  const NotificationOpen({required this.type, this.clientTxnId, this.action});

  /// 'payee', 'items' or 'summary'.
  final String type;
  final String? clientTxnId;

  /// Button id, or null for a tap on the notification itself.
  final String? action;

  static NotificationOpen? fromResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload) as Map;
      final action = response.actionId;
      return NotificationOpen(
        type: data['t'] as String,
        clientTxnId: data['id'] as String?,
        action: action == null || action.isEmpty ? null : action,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Button ids. Buttons marked "background" are answered without opening the app.
class PromptActions {
  const PromptActions._();
  static const shop = 'shop'; // opens the confirmation screen
  static const person = 'person'; // background
  static const yes = 'yes'; // background
  static const somethingElse = 'other'; // opens the item screen
  static const notAShop = 'not_shop'; // background
  static const open = 'open'; // opens the list of payments to tag
}

/// Prompts as Android notifications.
class LocalNotifications implements PromptNotifier, NotificationPermissions {
  LocalNotifications({this._backgroundHandler});

  /// Top-level function run in a background isolate for background buttons.
  final DidReceiveBackgroundNotificationResponseCallback? _backgroundHandler;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _promptChannel = AndroidNotificationChannel(
    'payment_prompts',
    'Payment prompts',
    description: 'Asks which shop a payment went to and what you bought.',
    importance: Importance.high,
  );
  static const _summaryChannel = AndroidNotificationChannel(
    'daily_summary',
    'Daily summary',
    description: 'One evening reminder when several payments are still untagged.',
    importance: Importance.defaultImportance,
  );

  /// Call once per isolate. [onOpen] is only meaningful in the UI isolate.
  Future<void> initialize({void Function(NotificationOpen open)? onOpen}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      onDidReceiveNotificationResponse: onOpen == null
          ? null
          : (response) {
              final open = NotificationOpen.fromResponse(response);
              if (open != null) onOpen(open);
            },
      onDidReceiveBackgroundNotificationResponse: onOpen == null ? null : _backgroundHandler,
    );
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// The notification that started the app, if any (cold start from a tap).
  Future<NotificationOpen?> launchOpen() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp || response == null) return null;
    return NotificationOpen.fromResponse(response);
  }

  /// Shows the Android 13+ permission prompt. True when notifications are allowed.
  @override
  Future<bool> request() async {
    await _ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> enabled() async {
    await _ensureInitialized();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  NotificationDetails _details(AndroidNotificationChannel channel, List<AndroidNotificationAction> actions) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel == _promptChannel ? Priority.high : Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
          // The exact amount is in the text: keep it off the lock screen.
          visibility: NotificationVisibility.private,
          // Marigold accent behind the small icon, as in the design.
          color: AppColors.light.brand,
          actions: actions,
        ),
      );

  @override
  Future<void> showPayeePrompt({required String clientTxnId, required String title, required String body}) async {
    await _ensureInitialized();
    await _plugin.show(
      id: notificationId(clientTxnId),
      title: title,
      body: body,
      payload: jsonEncode({'t': 'payee', 'id': clientTxnId}),
      notificationDetails: _details(_promptChannel, const [
        AndroidNotificationAction(PromptActions.shop, 'Shop', showsUserInterface: true),
        AndroidNotificationAction(PromptActions.person, 'Person'),
      ]),
    );
  }

  @override
  Future<void> showItemsPrompt({
    required String clientTxnId,
    required String title,
    required String body,
    required bool hasGuess,
  }) async {
    await _ensureInitialized();
    await _plugin.show(
      id: notificationId(clientTxnId),
      title: title,
      body: body,
      payload: jsonEncode({'t': 'items', 'id': clientTxnId}),
      notificationDetails: _details(_promptChannel, [
        if (hasGuess) const AndroidNotificationAction(PromptActions.yes, 'Yes'),
        AndroidNotificationAction(
          PromptActions.somethingElse,
          hasGuess ? 'Something else' : 'Add items',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(PromptActions.notAShop, 'Not a shop'),
      ]),
    );
  }

  @override
  Future<void> scheduleSummary({required int count, required DateTime at}) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: summaryNotificationId,
      title: summaryText(count),
      body: summaryBody,
      // An absolute instant; no time zone database is needed for that.
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      payload: jsonEncode({'t': 'summary'}),
      notificationDetails: _details(_summaryChannel, const [
        AndroidNotificationAction(PromptActions.open, 'Open', showsUserInterface: true),
      ]),
      // Inexact on purpose: no exact-alarm permission is requested.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(String clientTxnId) async {
    await _ensureInitialized();
    await _plugin.cancel(id: notificationId(clientTxnId));
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
