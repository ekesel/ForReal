import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/transaction_source.dart';
import '../core/providers.dart';
import '../data/db/database.dart';
import '../data/models.dart';

/// Read models for the screens.

/// Every local payment, newest first.
final transactionsProvider =
    StreamProvider<List<LocalTransaction>>((ref) => ref.watch(localStoreProvider).watchAll());

final transactionProvider = StreamProvider.family<LocalTransaction?, String>(
  (ref, clientTxnId) => ref.watch(localStoreProvider).watch(clientTxnId),
);

final unparsedMessagesProvider =
    StreamProvider<List<UnparsedMessage>>((ref) => ref.watch(localStoreProvider).watchUnparsed());

/// Whether Android lets the app see SMS. Invalidate after asking or on resume.
final smsPermissionProvider =
    FutureProvider<SmsPermission>((ref) => ref.watch(captureControlProvider).smsPermission());

final locationPermissionProvider = FutureProvider<bool>((ref) => ref.watch(locationServiceProvider).hasPermission());

final notificationsEnabledProvider =
    FutureProvider<bool>((ref) => ref.watch(notificationPermissionsProvider).enabled());

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(merchantsApiProvider).categories());
