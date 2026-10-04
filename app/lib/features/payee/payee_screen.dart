import 'dart:async';

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

/// "Shop or person?" for the payee of one payment, in up to three steps on one
/// route: the choice, which shop, and adding a shop. The answer applies to every
/// payment to that payee. Also used to correct an earlier answer.
class PayeeScreen extends ConsumerWidget {
  const PayeeScreen({super.key, required this.clientTxnId});

  final String clientTxnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionProvider(clientTxnId));
    void back() => context.go('/txn/$clientTxnId');
    return Scaffold(
      body: transaction.when(
        loading: () => ScreenBody(children: [ScreenHeader(onBack: back), const SkeletonList(rows: 2)]),
        error: (e, _) => ScreenBody(children: [ScreenHeader(onBack: back), ErrorState(message: errorText(e))]),
        data: (row) => row == null || row.payeeId == null
            ? ScreenBody(children: [
                ScreenHeader(onBack: back),
                const EmptyState(
                  icon: LucideIcons.cloudOff,
                  title: 'Not uploaded yet',
                  body: 'This payment has not reached the server yet. Try again in a moment.',
                ),
              ])
            : _PayeeFlow(row: row),
      ),
    );
  }
}

enum _Stage { choose, whichShop, addShop }

class _PayeeFlow extends ConsumerStatefulWidget {
  const _PayeeFlow({required this.row});

  final LocalTransaction row;

  @override
  ConsumerState<_PayeeFlow> createState() => _PayeeFlowState();
}

class _PayeeFlowState extends ConsumerState<_PayeeFlow> {
  _Stage _stage = _Stage.choose;
  bool _shop = true;

  /// Where the user is now, only if the payment just happened (see PayeeService.hereFor).
  LatLng? _here;
  List<Merchant>? _suggestions;
  List<Merchant>? _results;
  String? _searchError;
  Timer? _debounce;
  final _search = TextEditingController();

  // Add a shop.
  final _name = TextEditingController();
  String? _category;
  bool _online = false;

  LocalTransaction get _row => widget.row;

  @override
  void initState() {
    super.initState();
    _shop = _row.kind != 'person';
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = ref.read(payeeServiceProvider);
    final here = await service.hereFor(_row);
    if (mounted) setState(() => _here = here);
    try {
      final suggestions = await service.suggestions(_row, here: here);
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      setState(() {
        _results = null;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found = await ref.read(payeeServiceProvider).search(query, here: _here);
        if (mounted && _search.text.trim() == query) {
          setState(() {
            _results = found;
            _searchError = null;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _searchError = errorText(e));
      }
    });
  }

  void _done(String message) {
    if (!mounted) return;
    showMessage(context, message);
    context.go('/txn/${_row.clientTxnId}');
  }

  void _back() {
    switch (_stage) {
      case _Stage.choose:
        context.go('/txn/${_row.clientTxnId}');
      case _Stage.whichShop:
        setState(() => _stage = _Stage.choose);
      case _Stage.addShop:
        setState(() => _stage = _Stage.whichShop);
    }
  }

  Future<void> _continue() async {
    if (_shop) {
      setState(() => _stage = _Stage.whichShop);
      return;
    }
    await ref.read(payeeServiceProvider).markPerson(_row);
    _done('Marked as a person. These payments stay private.');
  }

  Future<void> _choose(Merchant merchant) async {
    try {
      await ref.read(payeeServiceProvider).chooseMerchant(_row, merchant, here: _here);
      _done('Saved as ${merchant.name}.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty || _category == null) {
      showMessage(context, 'Enter the shop name and pick what kind of place it is.');
      return;
    }
    await ref.read(payeeServiceProvider).addMerchant(
          _row,
          NewMerchant(name: name, category: _category!, isOnline: _online),
          here: _here,
        );
    _done('Saved as $name.');
  }

  String _merchantLine(Merchant merchant) =>
      merchant.isOnline ? '${categoryLabel(merchant.category)} · online' : categoryLabel(merchant.category);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.quick,
      child: KeyedSubtree(
        key: ValueKey(_stage),
        child: switch (_stage) {
          _Stage.choose => _chooseStage(),
          _Stage.whichShop => _whichShopStage(),
          _Stage.addShop => _addShopStage(),
        },
      ),
    );
  }

  // --- 1. shop or person -------------------------------------------------------

  Widget _chooseStage() {
    final c = context.colors;
    final all = ref.watch(transactionsProvider).value ?? const <LocalTransaction>[];
    final count = all.where((t) => t.payeeId == _row.payeeId).length;
    final current = _row.merchantInfo;
    final facts = [
      amountText(_row),
      dayAndTime(_row.receivedAt, now: ref.watch(clockProvider)()).replaceFirst('Today', 'today').replaceFirst('Yesterday', 'yesterday'),
      if (count > 1) '$count payments so far',
    ].join(' · ');
    final unchangedPerson = !_shop && _row.kind == 'person';
    return ScreenBody(
      actions: [AppButton(label: 'Continue', onPressed: unchangedPerson ? null : _continue)],
      children: [
        ScreenHeader(title: _row.kind == 'unknown' ? 'New payee' : 'Change payee', onBack: _back),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('You paid'),
            const SizedBox(height: 6),
            Text(_row.payeeDisplay, style: AppText.displayL.copyWith(color: c.ink)),
            const SizedBox(height: 6),
            Text(facts, style: AppText.bodyM.copyWith(color: c.inkMuted)),
            if (current != null) ...[
              const SizedBox(height: 6),
              Text('Currently: ${current.name}', style: AppText.bodyM.copyWith(color: c.inkMuted)),
            ] else if (_row.kind == 'person') ...[
              const SizedBox(height: 6),
              Text('Currently: a person', style: AppText.bodyM.copyWith(color: c.inkMuted)),
            ],
          ],
        ),
        Text('Is this a shop or a person?', style: AppText.titleL.copyWith(color: c.ink)),
        _ChoiceCard(
          icon: LucideIcons.store,
          title: 'A shop',
          body: 'Counts in local rankings, with no name attached.',
          selected: _shop,
          onTap: () => setState(() => _shop = true),
        ),
        _ChoiceCard(
          icon: LucideIcons.user,
          title: 'A person',
          body: 'Stays private. Never counted or shared.',
          selected: !_shop,
          onTap: () => setState(() => _shop = false),
        ),
        Row(
          children: [
            Icon(LucideIcons.repeat, size: 16, color: c.inkMuted),
            const SizedBox(width: AppSpace.x8),
            Expanded(
              child: Text(
                'Applies to every payment to this name. Change it any time.',
                style: AppText.caption.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. which shop -------------------------------------------------------------

  Widget _whichShopStage() {
    final c = context.colors;
    final suggestions = _suggestions;
    final results = _results;
    return ScreenBody(
      gap: 18,
      actions: [
        AppButton(
          label: 'Add a new shop',
          variant: AppButtonVariant.secondary,
          onPressed: () => setState(() {
            _stage = _Stage.addShop;
            if (_name.text.isEmpty) _name.text = _search.text.trim();
          }),
        ),
      ],
      children: [
        ScreenHeader(title: 'Which shop is it?', onBack: _back),
        AppTextField(
          controller: _search,
          prefixIcon: LucideIcons.search,
          hint: 'Search shops near you',
          errorText: _searchError,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
        ),
        if (suggestions == null)
          const SkeletonList(rows: 1)
        else if (suggestions.isNotEmpty) ...[
          const SectionLabel('People nearby say'),
          for (final merchant in suggestions)
            AppCard(
              radius: AppRadius.r24,
              // Green: other people's real payments confirmed this shop.
              borderColor: c.real,
              child: Column(
                children: [
                  Row(
                    children: [
                      AvatarBox(letter: initialOf(merchant.name), color: c.realSoft, foreground: c.real),
                      const SizedBox(width: AppSpace.x12),
                      Expanded(child: _MerchantText(name: merchant.name, line: _merchantLine(merchant))),
                    ],
                  ),
                  const SizedBox(height: AppSpace.x8),
                  Row(
                    children: [
                      const Flexible(child: AppChip(label: 'Confirmed nearby', variant: AppChipVariant.real)),
                      const SizedBox(width: AppSpace.x8),
                      const Spacer(),
                      AppButton(label: 'That’s it', expand: false, onPressed: () => _choose(merchant)),
                    ],
                  ),
                ],
              ),
            ),
        ],
        if (results != null) ...[
          const SectionLabel('Matching shops'),
          if (results.isEmpty)
            Text('No shop found with that name. You can add it below.', style: AppText.bodyM.copyWith(color: c.inkMuted))
          else
            Column(
              children: [
                for (final merchant in results) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: 14),
                    onTap: () => _choose(merchant),
                    child: Row(
                      children: [
                        AvatarBox(letter: initialOf(merchant.name)),
                        const SizedBox(width: AppSpace.x12),
                        Expanded(child: _MerchantText(name: merchant.name, line: _merchantLine(merchant))),
                        Icon(LucideIcons.chevronRight, size: 18, color: c.inkMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.x8),
                ],
              ],
            ),
        ] else if (suggestions != null && suggestions.isEmpty)
          Text(
            'Nobody nearby has named this payee yet. Search for the shop, or add it.',
            style: AppText.bodyM.copyWith(color: c.inkMuted),
          ),
      ],
    );
  }

  // --- 3. add a shop --------------------------------------------------------------

  Widget _addShopStage() {
    final c = context.colors;
    final categories = ref.watch(categoriesProvider);
    return ScreenBody(
      actions: [AppButton(label: 'Save shop', onPressed: _add)],
      children: [
        ScreenHeader(title: 'Add a shop', onBack: _back),
        AppTextField(
          controller: _name,
          label: 'Shop name',
          hint: 'What people call it',
          helper: 'Your bank calls them ${_row.payeeDisplay}',
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What kind of place?', style: AppText.labelM.copyWith(color: c.inkMuted)),
            const SizedBox(height: 2),
            categories.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.x12),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Row(
                children: [
                  Expanded(child: Text(errorText(e), style: AppText.bodyM.copyWith(color: c.inkMuted))),
                  AppButton(
                    label: 'Retry',
                    variant: AppButtonVariant.ghost,
                    expand: false,
                    onPressed: () => ref.invalidate(categoriesProvider),
                  ),
                ],
              ),
              data: (list) => Wrap(
                spacing: AppSpace.x8,
                children: [
                  for (final category in list)
                    AppChip(
                      label: category.name,
                      variant: _category == category.slug ? AppChipVariant.selected : AppChipVariant.normal,
                      onTap: () => setState(() => _category = category.slug),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_here != null && !_online)
          AppCard(
            outlined: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(AppRadius.r14)),
                    child: Icon(LucideIcons.mapPin, size: 20, color: c.ink),
                  ),
                ),
                const SizedBox(width: AppSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Near where you are now', style: AppText.titleM.copyWith(color: c.ink)),
                      const SizedBox(height: 2),
                      Text('Saved roughly, to about 100 metres', style: AppText.bodyM.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Online or no fixed place', style: AppText.titleM.copyWith(color: c.ink)),
                  const SizedBox(height: 2),
                  Text('Like Swiggy or Rapido', style: AppText.bodyM.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.x12),
            AppToggle(
              value: _online,
              onChanged: (v) => setState(() => _online = v),
              semanticLabel: 'Online or no fixed place',
            ),
          ],
        ),
      ],
    );
  }
}

class _MerchantText extends StatelessWidget {
  const _MerchantText({required this.name, required this.line});

  final String name;
  final String line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.titleM.copyWith(color: c.ink)),
        const SizedBox(height: 2),
        Text(line, style: AppText.bodyM.copyWith(color: c.inkMuted)),
      ],
    );
  }
}

/// "A shop" or "A person". The selected card is ink.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppCard(
        radius: AppRadius.r24,
        padding: const EdgeInsets.all(18),
        color: selected ? c.ink : c.surface,
        outlined: !selected,
        onTap: onTap,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected ? c.brand : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                ),
                child: Icon(icon, size: 24, color: selected ? c.onBrand : c.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleM.copyWith(color: selected ? c.onInk : c.ink)),
                  const SizedBox(height: 3),
                  Text(body, style: AppText.bodyM.copyWith(color: selected ? c.inkFaint : c.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
