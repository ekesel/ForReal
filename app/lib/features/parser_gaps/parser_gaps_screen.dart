import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../ui_providers.dart';

/// Every digit becomes X, so amounts, account digits, references, phone numbers
/// and OTPs cannot be read back from a copied message.
String maskDigits(String text) => text.replaceAll(RegExp(r'\d'), 'X');

/// What "Copy" puts on the clipboard for one message.
String gapReport(UnparsedMessage message) => 'Sender: ${maskDigits(message.sender)}\n${maskDigits(message.body)}';

/// Debug builds only. Bank messages no template matched, masked, so a new bank
/// format can be reported without leaking anything.
class ParserGapsScreen extends ConsumerWidget {
  const ParserGapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final messages = ref.watch(unparsedMessagesProvider);
    final header = ScreenHeader(title: 'Parser gaps', onBack: () => context.go('/settings'));
    return Scaffold(
      body: messages.when(
        loading: () => ScreenBody(children: [header, const SkeletonList(rows: 3)]),
        error: (e, _) => ScreenBody(children: [header, ErrorState(message: errorText(e))]),
        data: (rows) => rows.isEmpty
            ? ScreenBody(children: [
                header,
                const EmptyState(
                  icon: LucideIcons.check,
                  title: 'No gaps',
                  body: 'Every message from a known bank matched a template or was a credit.',
                ),
              ])
            : ScreenBody(
                gap: AppSpace.x8,
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.x8),
                    child: InfoBanner(
                      icon: LucideIcons.lock,
                      text: '${rows.length} bank messages matched no template. Digits are masked. '
                          'They never leave this phone unless you copy one.',
                    ),
                  ),
                  for (final message in rows)
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(AppSpace.x16, AppSpace.x12, AppSpace.x4, AppSpace.x12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${maskDigits(message.sender)} · ${dayAndTime(message.receivedAt)}',
                                  style: AppText.labelS.copyWith(color: c.inkMuted),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(maskDigits(message.body), style: AppText.bodyM.copyWith(color: c.ink)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy masked text',
                            icon: Icon(LucideIcons.copy, size: 20, color: c.ink),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: gapReport(message)));
                              if (context.mounted) showMessage(context, 'Masked message copied.');
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
