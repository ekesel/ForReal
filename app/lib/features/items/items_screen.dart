import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../home/payment_list.dart';
import '../ui_providers.dart';

/// "What did you get?" The current tags (the app's guesses or the user's earlier
/// answer) start selected.
class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key, required this.clientTxnId});

  final String clientTxnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionProvider(clientTxnId));
    void back() => context.go('/txn/$clientTxnId');
    Widget message(IconData icon, String title, String body) => ScreenBody(children: [
          ScreenHeader(title: 'What did you get?', onBack: back),
          EmptyState(icon: icon, title: title, body: body),
        ]);
    return Scaffold(
      body: transaction.when(
        loading: () => ScreenBody(children: [
          ScreenHeader(title: 'What did you get?', onBack: back),
          const SkeletonList(rows: 2),
        ]),
        error: (e, _) => ScreenBody(children: [
          ScreenHeader(title: 'What did you get?', onBack: back),
          ErrorState(message: errorText(e)),
        ]),
        data: (row) {
          if (row == null || row.serverId == null) {
            return message(LucideIcons.cloudOff, 'Not uploaded yet',
                'This payment has not reached the server yet. Try again in a moment.');
          }
          if (row.kind == 'person') {
            return message(LucideIcons.lock, 'Private', 'Payments to a person are private and are not tagged.');
          }
          if (row.kind != 'merchant') {
            return message(LucideIcons.store, 'Which shop first', 'Say which shop this was, then tag what you got.');
          }
          return _ItemsForm(key: ValueKey(row.clientTxnId), row: row);
        },
      ),
    );
  }
}

/// One selectable thing: a catalogue item, or free text the user typed.
class _Choice {
  _Choice.item(Item this.item) : name = item.name;
  _Choice.custom(this.name) : item = null;

  final Item? item;
  final String name;

  String get key => item != null ? 'i${item!.id}' : 'n${name.toLowerCase()}';
}

/// "Our guess: Tea × 2, Samosa, from your last visits"
String guessSentence(List<({String name, int quantity})> guesses, {String? origin}) {
  final list = [for (final g in guesses) g.quantity > 1 ? '${g.name} × ${g.quantity}' : g.name].join(', ');
  final source = switch (origin) {
    'ai_own_history' => ', from your last visits',
    'ai_crowd' => ', from what others get here',
    _ => '',
  };
  return 'Our guess: $list$source';
}

class _ItemsForm extends ConsumerStatefulWidget {
  const _ItemsForm({super.key, required this.row});

  final LocalTransaction row;

  @override
  ConsumerState<_ItemsForm> createState() => _ItemsFormState();
}

class _ItemsFormState extends ConsumerState<_ItemsForm> {
  final Map<String, _Choice> _choices = {};
  final Map<String, int> _selected = {};
  late final Map<String, int> _initial;
  String? _guess;
  bool _loading = true;
  String? _loadError;

  LocalTransaction get _row => widget.row;

  @override
  void initState() {
    super.initState();
    // Suggested items are preselected.
    final tags = _row.taggedItems;
    for (final tag in tags) {
      final choice = _Choice.item(tag.item);
      _choices[choice.key] = choice;
      _selected[choice.key] = tag.quantity;
    }
    _initial = Map.of(_selected);
    final guessed = [for (final t in tags) if (t.inferred) t];
    if (guessed.isNotEmpty) {
      _guess = guessSentence(
        [for (final t in guessed) (name: t.item.name, quantity: t.quantity)],
        origin: guessed.first.origin,
      );
    }
    _loadChips();
  }

  Future<void> _loadChips() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final service = ref.read(itemsServiceProvider);
      final chips = await service.chips(_row);
      // A payment without stored guesses may still have suggestions by now (for
      // example from the user's own later answers at this shop): preselect those.
      final suggested = _row.taggedItems.isEmpty ? (await service.suggestions(_row)).suggestions : const <ItemSuggestion>[];
      if (!mounted) return;
      setState(() {
        for (final item in chips) {
          final choice = _Choice.item(item);
          _choices.putIfAbsent(choice.key, () => choice);
        }
        for (final suggestion in suggested) {
          final choice = _Choice.item(suggestion.item);
          _choices.putIfAbsent(choice.key, () => choice);
          _selected.putIfAbsent(choice.key, () => suggestion.quantity);
        }
        if (suggested.isNotEmpty) {
          _guess = guessSentence(
            [for (final s in suggested) (name: s.item.name, quantity: s.quantity)],
            origin: suggested.first.origin,
          );
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = errorText(e);
        });
      }
    }
  }

  void _toggle(_Choice choice) {
    setState(() {
      if (_selected.containsKey(choice.key)) {
        _selected.remove(choice.key);
      } else {
        _selected[choice.key] = 1;
      }
    });
  }

  Future<void> _addYourOwn() async {
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
              label: 'Add your own',
              hint: 'What was it?',
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: AppSpace.x16),
            AppButton(label: 'Add', onPressed: () => Navigator.of(context).pop(controller.text)),
          ],
        ),
      ),
    );
    final typed = name?.trim() ?? '';
    if (typed.isEmpty || !mounted) return;
    // Typing the name of an existing chip selects that chip.
    final existing = _choices.values.where((c) => c.name.toLowerCase() == typed.toLowerCase()).firstOrNull;
    final choice = existing ?? _Choice.custom(typed);
    setState(() {
      _choices.putIfAbsent(choice.key, () => choice);
      _selected.putIfAbsent(choice.key, () => 1);
    });
  }

  void _step(String key, int delta) {
    setState(() => _selected[key] = (_selected[key]! + delta).clamp(1, 99));
  }

  bool get _unchanged =>
      _selected.length == _initial.length && _selected.entries.every((e) => _initial[e.key] == e.value);

  /// The one-tap confirmation is offered while the screen still shows the app's
  /// guesses exactly as they came.
  bool get _canConfirm => _unchanged && _row.taggedItems.isNotEmpty && _row.taggedItems.any((t) => t.inferred);

  void _done(String message) {
    if (!mounted) return;
    showMessage(context, message);
    context.go('/txn/${_row.clientTxnId}');
  }

  Future<void> _confirm() async {
    await ref.read(itemsServiceProvider).confirm(_row);
    _done('Thanks, saved.');
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      showMessage(context, 'Pick at least one thing.');
      return;
    }
    final entries = [
      for (final e in _selected.entries)
        _choices[e.key]!.item != null
            ? ItemEntry.catalogue(_choices[e.key]!.item!.id, e.value)
            : ItemEntry.named(_choices[e.key]!.name, e.value),
    ];
    await ref.read(itemsServiceProvider).save(_row, entries);
    _done('Saved.');
  }

  Future<void> _notAShop() async {
    final ok = await confirmDialog(
      context,
      title: 'Not a shop?',
      message: 'Every payment to ${_row.payeeDisplay} becomes a payment to a person: private, untagged, never counted.',
      confirmLabel: 'Yes, it’s a person',
    );
    if (!ok) return;
    await ref.read(payeeServiceProvider).markPerson(_row);
    _done('Marked as a person. These payments stay private.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedKeys = _selected.keys.toList();
    // Selected first, in the order they were picked; the rest alphabetical.
    final rest = [for (final c in _choices.values) if (!_selected.containsKey(c.key)) c]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final choices = [for (final key in selectedKeys) _choices[key]!, ...rest];
    return ScreenBody(
      gap: 18,
      actions: [
        _canConfirm
            ? AppButton(label: 'Yes, correct', icon: LucideIcons.check, onPressed: _confirm)
            : AppButton(label: 'Save', onPressed: _save),
        AppButton(label: 'This isn’t a shop', variant: AppButtonVariant.ghost, quiet: true, onPressed: _notAShop),
      ],
      children: [
        ScreenHeader(title: 'What did you get?', onBack: () => context.go('/txn/${_row.clientTxnId}')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: 14),
          child: Row(
            children: [
              AvatarBox(letter: initialOf(_row.title)),
              const SizedBox(width: AppSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _row.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleM.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(dayAndTime(_row.receivedAt, now: ref.watch(clockProvider)()), style: AppText.bodyM.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.x12),
              Text(amountText(_row), style: AppText.titleL.copyWith(color: c.ink)),
            ],
          ),
        ),
        // A guess is marigold and has a spark; it is never green.
        if (_guess != null) InfoBanner(icon: LucideIcons.sparkle, tone: BannerTone.brand, text: _guess!),
        const SectionLabel('Pick everything you got'),
        if (_loadError != null)
          Row(
            children: [
              Expanded(child: Text(_loadError!, style: AppText.bodyM.copyWith(color: c.inkMuted))),
              AppButton(label: 'Retry', variant: AppButtonVariant.ghost, expand: false, onPressed: _loadChips),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(),
            Wrap(
              spacing: AppSpace.x8,
              children: [
                for (final choice in choices)
                  AppChip(
                    label: choice.name,
                    variant: _selected.containsKey(choice.key) ? AppChipVariant.selected : AppChipVariant.normal,
                    onTap: () => _toggle(choice),
                  ),
                AppChip(
                  label: 'Add your own',
                  variant: AppChipVariant.guess,
                  icon: LucideIcons.plus,
                  semanticLabel: 'Add your own',
                  onTap: _addYourOwn,
                ),
              ],
            ),
          ],
        ),
        if (selectedKeys.isNotEmpty) ...[
          const SectionLabel('How many?'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: AppSpace.x4),
            child: Column(
              children: [
                for (var i = 0; i < selectedKeys.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: i == selectedKeys.length - 1 ? null : Border(bottom: BorderSide(color: c.line)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.x4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _choices[selectedKeys[i]]!.name,
                            style: AppText.titleM.copyWith(color: c.ink),
                          ),
                        ),
                        _StepButton(
                          icon: LucideIcons.minus,
                          label: 'Fewer',
                          filled: false,
                          onPressed: _selected[selectedKeys[i]]! > 1 ? () => _step(selectedKeys[i], -1) : null,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${_selected[selectedKeys[i]]}',
                            textAlign: TextAlign.center,
                            style: AppText.titleL.copyWith(color: c.ink),
                          ),
                        ),
                        _StepButton(
                          icon: LucideIcons.plus,
                          label: 'More',
                          filled: true,
                          onPressed: _selected[selectedKeys[i]]! < 99 ? () => _step(selectedKeys[i], 1) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A 34 px round stepper button in a 48 px touch target.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.filled, required this.onPressed});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: 26,
          child: SizedBox(
            width: AppSize.touch,
            height: AppSize.touch,
            child: Center(
              child: Opacity(
                opacity: onPressed == null ? 0.4 : 1,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: filled ? c.ink : c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: filled ? c.onInk : c.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
