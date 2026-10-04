import 'dart:ui';

import 'package:flutter/services.dart';

import 'raw_message.dart';
import 'transaction_source.dart';

/// The Android SMS capture module, seen from Dart. This file is the only place in
/// the app that talks to the Kotlin side (android/.../capture/CaptureChannel.kt).
class AndroidSmsSource implements TransactionSource, CaptureControl {
  AndroidSmsSource({required this._backgroundEntryPoint});

  /// Top-level function Kotlin runs in a headless engine to process the queue.
  final Function _backgroundEntryPoint;

  static const _methods = MethodChannel('forreal/capture');
  static const _events = EventChannel('forreal/capture/messages');
  static const _historyPageSize = 100;

  Stream<RawMessage>? _messages;

  @override
  Stream<RawMessage> get messages => _messages ??= _events
      .receiveBroadcastStream()
      .map((event) => RawMessage.fromPlatform(event as Map<Object?, Object?>));

  @override
  Future<List<RawMessage>> drainQueue() async {
    final rows = await _methods.invokeListMethod<Map<Object?, Object?>>('drainQueue', {'limit': 50});
    return [for (final row in rows ?? const <Map<Object?, Object?>>[]) RawMessage.fromPlatform(row)];
  }

  @override
  Future<void> acknowledge(List<RawMessage> processed) async {
    final ids = [
      for (final m in processed)
        if (m.queueId != null) m.queueId!,
    ];
    if (ids.isEmpty) return;
    await _methods.invokeMethod<void>('acknowledge', ids);
  }

  @override
  Future<List<RawMessage>> history(DateTime since, {int page = 0}) async {
    final rows = await _methods.invokeListMethod<Map<Object?, Object?>>('history', {
      'since': since.millisecondsSinceEpoch,
      'page': page,
      'pageSize': _historyPageSize,
    });
    return [for (final row in rows ?? const <Map<Object?, Object?>>[]) RawMessage.fromPlatform(row)];
  }

  @override
  Future<void> setAllowedSenders(Set<String> codes) =>
      _methods.invokeMethod<void>('setAllowedSenders', codes.toList());

  @override
  Future<void> setCaptureEnabled(bool enabled) => _methods.invokeMethod<void>('setCaptureEnabled', enabled);

  @override
  Future<void> clearQueue() => _methods.invokeMethod<void>('clearQueue');

  @override
  Future<SmsPermission> smsPermission() async => _permission(await _methods.invokeMethod<String>('smsPermissionStatus'));

  @override
  Future<SmsPermission> requestSmsPermission() async =>
      _permission(await _methods.invokeMethod<String>('requestSmsPermission'));

  @override
  Future<void> registerBackgroundEntryPoint() async {
    final handle = PluginUtilities.getCallbackHandle(_backgroundEntryPoint);
    if (handle == null) return;
    await _methods.invokeMethod<void>('registerBackgroundCallback', handle.toRawHandle());
  }

  /// Why the headless engine was started: 'sms', 'network' or 'periodic'.
  Future<String> backgroundReason() async => await _methods.invokeMethod<String>('backgroundReason') ?? 'sms';

  /// Ends a background run. [retry] asks for another run once there is a connection.
  Future<void> backgroundDone({required bool retry}) =>
      _methods.invokeMethod<void>('backgroundDone', {'retry': retry});

  SmsPermission _permission(String? status) => switch (status) {
        'granted' => SmsPermission.granted,
        'denied_forever' => SmsPermission.deniedForever,
        _ => SmsPermission.denied,
      };
}
