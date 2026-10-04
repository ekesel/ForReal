import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter/widgets.dart';

import '../../core/format.dart';
import '../../core/widgets/payment_row.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';

/// How the home screen arranges payments. Pure functions over local rows; nothing
/// here talks to the server.

enum PaymentFilter { all, needsYou, shops, people }

bool matchesFilter(LocalTransaction row, PaymentFilter filter) => switch (filter) {
      PaymentFilter.all => true,
      PaymentFilter.needsYou => row.needsAttention,
      PaymentFilter.shops => row.kind == 'merchant',
      PaymentFilter.people => row.kind == 'person',
    };

/// The five visual states. A shop payment whose tags are all the app's guesses is
/// "guessed", never "done": only the user's own answer turns a row green.
PaymentRowState rowStateOf(LocalTransaction row) {
  if (row.kind == 'person') return PaymentRowState.person;
  if (row.kind != 'merchant') return PaymentRowState.needsShop;
  final tags = row.taggedItems;
  if (tags.isEmpty) return PaymentRowState.needsItems;
  return tags.every((t) => !t.inferred) ? PaymentRowState.done : PaymentRowState.guessed;
}

/// "Tea × 2 · Samosa"
String itemsText(LocalTransaction row) => [
      for (final tag in row.taggedItems) tag.quantity > 1 ? '${tag.item.name} × ${tag.quantity}' : tag.item.name,
    ].join(' · ');

/// The exact amount when this phone has it, otherwise the range the server knows.
String amountText(LocalTransaction row) =>
    row.amountExact != null ? formatRupees(row.amountExact!) : bandLabel(row.amountBand);

/// A small mark for rows that are not on the server yet.
({IconData icon, String label})? syncMark(LocalTransaction row) => switch (row.syncState) {
      'pending' => (icon: LucideIcons.cloudOff, label: 'Waiting to upload'),
      'failed' => (icon: LucideIcons.alertCircle, label: 'Not uploaded'),
      _ => null,
    };

class DayGroup {
  const DayGroup(this.label, this.rows);

  /// "Today", "Yesterday", or a date.
  final String label;
  final List<LocalTransaction> rows;
}

/// Groups rows (already newest first) by the local day they were received.
List<DayGroup> groupByDay(List<LocalTransaction> rows, {DateTime? now}) {
  final groups = <DayGroup>[];
  DateTime? currentDay;
  for (final row in rows) {
    final local = row.receivedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (currentDay != day) {
      currentDay = day;
      groups.add(DayGroup(dayLabel(day, now: now), []));
    }
    groups.last.rows.add(row);
  }
  return groups;
}

class WeekSummary {
  const WeekSummary({required this.total, required this.count, required this.needsYou});

  /// Sum of the exact amounts this phone holds for the week. Computed locally;
  /// the server never has exact amounts.
  final double total;
  final int count;

  /// Payments (of any date) still waiting for an answer.
  final int needsYou;
}

/// This calendar week, Monday to now.
WeekSummary weekSummary(List<LocalTransaction> rows, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
  var total = 0.0;
  var count = 0;
  var needsYou = 0;
  for (final row in rows) {
    if (row.needsAttention) needsYou++;
    if (row.receivedAt.toLocal().isBefore(monday)) continue;
    count++;
    total += row.amountExact ?? 0;
  }
  return WeekSummary(total: total, count: count, needsYou: needsYou);
}
