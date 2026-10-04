import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/api/api_exception.dart';
import '../../features/consent/notices.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Text for any error a screen may catch.
String errorText(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';

void showError(BuildContext context, Object error) => showMessage(context, errorText(error));

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A consent notice or permission rationale in full, laid out the same way everywhere.
class NoticeView extends StatelessWidget {
  const NoticeView({super.key, required this.notice, this.showTitle = true, this.showWithdrawal = true});

  final Notice notice;
  final bool showTitle;
  final bool showWithdrawal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(notice.title, style: AppText.displayM.copyWith(color: c.ink)),
          const SizedBox(height: AppSpace.x12),
        ],
        Text(notice.summary, style: AppText.bodyL.copyWith(color: c.inkMuted)),
        const SizedBox(height: AppSpace.x16),
        for (final point in notice.points)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(LucideIcons.check, size: 16, color: c.ink),
                ),
                Expanded(child: Text(point, style: AppText.bodyM.copyWith(color: c.ink))),
              ],
            ),
          ),
        if (showWithdrawal && notice.withdrawal != null) ...[
          const SizedBox(height: AppSpace.x4),
          Text(notice.withdrawal!, style: AppText.caption.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final c = context.colors;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, AppSpace.x20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.displayM.copyWith(color: c.ink)),
              const SizedBox(height: AppSpace.x12),
              Text(message, style: AppText.bodyL.copyWith(color: c.inkMuted)),
              const SizedBox(height: AppSpace.x24),
              AppButton(
                label: confirmLabel,
                variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpace.x8),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Shows a notice in full. With [agreeLabel] it asks for agreement and returns
/// whether the user agreed; without it, it is read-only.
Future<bool> noticeSheet(BuildContext context, Notice notice, {String? agreeLabel}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, AppSpace.x20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            NoticeView(notice: notice),
            const SizedBox(height: AppSpace.x20),
            if (agreeLabel != null) ...[
              AppButton(label: agreeLabel, onPressed: () => Navigator.of(context).pop(true)),
              const SizedBox(height: AppSpace.x8),
              AppButton(
                label: 'Not now',
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ] else
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
