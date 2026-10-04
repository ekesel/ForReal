import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../capture/transaction_source.dart';
import '../../core/config.dart';
import '../../core/feature_flags.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../app/app_coordinator.dart';
import '../consent/notices.dart';
import '../home/tab_scaffold.dart';
import '../session/session_controller.dart';
import '../ui_providers.dart';

/// The "You" tab: privacy and data.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Purpose? _busy;

  SessionController get _session => ref.read(sessionProvider.notifier);

  Future<void> _setConsent(Purpose purpose, bool granted) async {
    final notice = noticeFor(purpose);
    final name = consentLabels[purpose]!.title;
    if (granted) {
      if (!await noticeSheet(context, notice, agreeLabel: 'I agree')) return;
      if (purpose == Purpose.showName && !await _askDisplayName()) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Switch off "$name"?',
        message: purpose == Purpose.privateAnalytics
            ? withdrawPrivateAnalyticsWarning
            : notice.withdrawal ?? 'You can switch it on again at any time.',
        confirmLabel: 'Switch off',
        destructive: purpose == Purpose.privateAnalytics,
      );
      if (!ok) return;
    }
    setState(() => _busy = purpose);
    try {
      await _session.setConsent(purpose, granted);
      if (granted && purpose == Purpose.location) {
        await ref.read(locationServiceProvider).requestPermission();
        ref.invalidate(locationPermissionProvider);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server enforces the dependency rules; explain them in plain words.
      final parent = purpose.requires;
      showMessage(
        context,
        e.code == 'dependency' && parent != null ? 'Switch on "${consentLabels[parent]!.title}" first.' : e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// "Show my name" needs a name to show.
  Future<bool> _askDisplayName() async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.screen,
          0,
          AppSpace.screen,
          AppSpace.x20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: controller,
              label: 'Name to show',
              hint: 'How others will see you',
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpace.x16),
            AppButton(label: 'Save', onPressed: () => Navigator.of(context).pop(controller.text.trim())),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return false;
    try {
      await ref.read(accountApiProvider).setDisplayName(name);
      return true;
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
      return false;
    }
  }

  Future<void> _export() async {
    try {
      final data = await ref.read(accountApiProvider).export();
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'forreal-export.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'My ForReal data'),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete your account?',
      message: deleteAccountWarning,
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!ok) return;
    await _session.deleteAccount();
  }

  Future<void> _signOut() async {
    if (!await confirmDialog(context, title: 'Sign out?', message: signOutWarning, confirmLabel: 'Sign out')) return;
    await _session.signOut();
  }

  Future<void> _chooseImport() async {
    final months = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, AppSpace.x20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Import past payments', style: AppText.displayM.copyWith(color: context.colors.ink)),
              const SizedBox(height: AppSpace.x8),
              Text(
                'From bank messages already on this phone. No notifications for old ones.',
                style: AppText.bodyL.copyWith(color: context.colors.inkMuted),
              ),
              const SizedBox(height: AppSpace.x20),
              AppButton(label: 'Last month', onPressed: () => Navigator.of(context).pop(1)),
              const SizedBox(height: AppSpace.x8),
              AppButton(
                label: 'Last 3 months',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(3),
              ),
            ],
          ),
        ),
      ),
    );
    if (months == null) return;
    try {
      final count = await ref.read(appCoordinatorProvider).importHistory(Duration(days: 30 * months));
      if (mounted) showMessage(context, count == 0 ? 'No new payments found.' : 'Imported $count payments.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(sessionProvider);
    final sms = ref.watch(smsPermissionProvider).value;
    final location = ref.watch(locationPermissionProvider).value ?? false;
    final notifications = ref.watch(notificationsEnabledProvider).value ?? false;
    final importing = ref.watch(historyImportRunningProvider);
    final canImport = !importing && sms == SmsPermission.granted && session.mayCapture;

    final purposes = [
      Purpose.privateAnalytics,
      Purpose.communityRankings,
      Purpose.showName,
      Purpose.location,
      if (merchantInsightsEnabled) Purpose.merchantInsights,
    ];

    return TabScaffold(
      tab: AppTab.you,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.x8, AppSpace.screen, AppSpace.x24),
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                  child: Icon(LucideIcons.user, size: 24, color: c.onInk),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('You', style: AppText.displayM.copyWith(color: c.ink))),
                    const SizedBox(height: 2),
                    Text(
                      session.phone.isEmpty ? 'Signed in' : maskPhone(session.phone),
                      style: AppText.bodyM.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('What you share'),
          const SizedBox(height: AppSpace.x12),
          _Group(
            children: [
              for (final purpose in purposes)
                _ConsentRow(
                  title: consentLabels[purpose]!.title,
                  subtitle: purpose.requires != null && !session.consents.has(purpose.requires!)
                      ? 'Needs "${consentLabels[purpose.requires!]!.title}"'
                      : consentLabels[purpose]!.line,
                  value: session.consents.has(purpose),
                  onChanged: _busy != null ? null : (v) => _setConsent(purpose, v),
                  onInfo: () => noticeSheet(context, noticeFor(purpose)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Phone permissions'),
          const SizedBox(height: AppSpace.x12),
          _Group(
            children: [
              _PermissionRow(
                icon: LucideIcons.messageSquare,
                title: 'Bank messages',
                status: sms == SmsPermission.granted ? 'Allowed' : 'Not allowed. Payments are not being recorded.',
                actionLabel: sms == SmsPermission.granted
                    ? null
                    : sms == SmsPermission.deniedForever
                        ? 'App settings'
                        : 'Allow',
                onAction: () async {
                  final result = sms == SmsPermission.deniedForever
                      ? SmsPermission.deniedForever
                      : await ref.read(captureControlProvider).requestSmsPermission();
                  if (result == SmsPermission.deniedForever) await ref.read(openAppSettingsProvider)();
                  ref.invalidate(smsPermissionProvider);
                },
              ),
              _PermissionRow(
                icon: LucideIcons.mapPin,
                title: 'Approximate location',
                status: !session.consents.has(Purpose.location)
                    ? 'Off'
                    : location
                        ? 'Allowed, only while the app is open'
                        : 'Not allowed on this phone',
                actionLabel: session.consents.has(Purpose.location) && !location ? 'Allow' : null,
                onAction: () async {
                  if (!await ref.read(locationServiceProvider).requestPermission()) {
                    await ref.read(openAppSettingsProvider)();
                  }
                  ref.invalidate(locationPermissionProvider);
                },
              ),
              _PermissionRow(
                icon: LucideIcons.bell,
                title: 'Notifications',
                status: notifications ? 'Allowed' : 'Off. Tag payments from the list instead.',
                actionLabel: notifications ? null : 'Allow',
                onAction: () async {
                  if (!await ref.read(notificationPermissionsProvider).request()) {
                    await ref.read(openAppSettingsProvider)();
                  }
                  ref.invalidate(notificationsEnabledProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Your data'),
          const SizedBox(height: AppSpace.x12),
          _Group(
            children: [
              _LinkRow(
                icon: LucideIcons.clock,
                title: importing ? 'Importing past payments…' : 'Import past payments',
                onTap: canImport ? _chooseImport : null,
              ),
              _LinkRow(icon: LucideIcons.download, title: 'Export my data', onTap: _export),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 18),
            const SectionLabel('Debug'),
            const SizedBox(height: AppSpace.x12),
            _Group(
              children: [
                _LinkRow(
                  icon: LucideIcons.bug,
                  title: 'Parser gaps',
                  onTap: () => context.go('/settings/parser-gaps'),
                ),
                _PermissionRow(icon: LucideIcons.server, title: 'Backend', status: AppConfig.apiBaseUrl),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.x24),
          AppButton(label: 'Sign out', variant: AppButtonVariant.secondary, quiet: true, onPressed: _signOut),
          const SizedBox(height: AppSpace.x8),
          AppButton(
            label: 'Delete account and all data',
            variant: AppButtonVariant.danger,
            quiet: true,
            onPressed: _delete,
          ),
          const SizedBox(height: AppSpace.x16),
          Text(
            'Area names $osmAttribution. Notice version $noticeVersion.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A surface card whose rows are separated by a line.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: AppSpace.x4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == children.length - 1 ? null : Border(bottom: BorderSide(color: c.line)),
              ),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.onInfo,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Opens the full notice.
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            hint: 'Shows what this means',
            child: InkWell(
              onTap: onInfo,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.titleM.copyWith(color: c.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.bodyM.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.x12),
        AppToggle(value: value, onChanged: onChanged, semanticLabel: title),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.title, required this.status, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String status;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.x12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.ink),
          const SizedBox(width: AppSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleM.copyWith(color: c.ink)),
                const SizedBox(height: 2),
                Text(status, style: AppText.bodyM.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          if (actionLabel != null)
            AppButton(label: actionLabel!, variant: AppButtonVariant.ghost, expand: false, onPressed: onAction),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;

  /// Null disables the row.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touch + 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c.ink),
                const SizedBox(width: AppSpace.x12),
                Expanded(child: Text(title, style: AppText.titleM.copyWith(color: c.ink))),
                Icon(LucideIcons.chevronRight, size: 18, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
