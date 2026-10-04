from collections import Counter, defaultdict

from django.conf import settings
from django.contrib.postgres.search import TrigramSimilarity
from django.db import transaction
from django.db.models import Count
from django.utils import timezone
from django.utils.text import slugify

from apps.common.text import normalize_item
from apps.consents.models import Purpose
from apps.consents.services import users_with_consent

from .models import Item, ItemAlias, Origin, TransactionItem

ITEM_MATCH_SIMILARITY = 0.65
OWN_HISTORY_LOOKBACK = 50


class TaggingError(Exception):
    pass


# --- catalogue ---------------------------------------------------------------

def resolve_item(name: str, user=None) -> Item:
    """Map free text to a catalogue item, creating an unverified one if nothing matches."""
    norm = normalize_item(name)
    alias = ItemAlias.objects.select_related("item").filter(alias=norm).first()
    if alias:
        return alias.item
    close = (
        Item.objects.annotate(sim=TrigramSimilarity("name", norm))
        .filter(sim__gte=ITEM_MATCH_SIMILARITY)
        .order_by("-sim")
        .first()
    )
    if close:
        return close
    base = slugify(norm)[:60] or "item"
    slug, n = base, 2
    while Item.objects.filter(slug=slug).exists():
        slug, n = f"{base}-{n}", n + 1
    item = Item.objects.create(name=norm.title()[:60], slug=slug, created_by=user)
    ItemAlias.objects.get_or_create(alias=norm, defaults={"item": item})
    return item


# --- suggestions ---------------------------------------------------------------

def _confirmed():
    """User-confirmed tags only. AI guesses never feed suggestions, so a wrong guess cannot spread."""
    return TransactionItem.objects.filter(origin=Origin.USER, rejected_at__isnull=True)


def _prefer_band(qs, band):
    same = qs.filter(transaction__amount_band=band)
    return same if same.exists() else qs


def _from_own_history(txn):
    qs = _prefer_band(
        _confirmed().filter(transaction__user=txn.user, transaction__payee=txn.payee).exclude(transaction=txn),
        txn.amount_band,
    )
    recent = list(
        qs.order_by("-transaction__occurred_on").values_list("transaction_id", "item_id", "quantity")[
            : OWN_HISTORY_LOOKBACK * 5
        ]
    )
    if not recent:
        return []
    visits = {t for t, _, _ in recent}
    per_item, quantities = Counter(), defaultdict(Counter)
    for _, item_id, qty in recent:
        per_item[item_id] += 1
        quantities[item_id][qty] += 1
    # Items bought on at least half the visits; failing that, the single most common one.
    picks = [i for i, n in per_item.items() if n * 2 >= len(visits)] or [per_item.most_common(1)[0][0]]
    items = Item.objects.in_bulk(picks)
    return [
        {
            "item": items[i],
            "quantity": quantities[i].most_common(1)[0][0],
            "origin": Origin.AI_OWN_HISTORY,
            "confidence": round(per_item[i] / len(visits), 2),
        }
        for i in picks
    ]


def _from_crowd(txn):
    if not txn.merchant_id:
        return []
    base = (
        _confirmed()
        .filter(transaction__merchant_id=txn.merchant_id, transaction__user__in=users_with_consent(Purpose.COMMUNITY_RANKINGS))
        .exclude(transaction__user=txn.user)
    )
    taggers = base.values("transaction__user").distinct().count()
    top = (
        _prefer_band(base, txn.amount_band)
        .values("item")
        .annotate(users=Count("transaction__user", distinct=True))
        .filter(users__gte=settings.CROWD_TAG_MIN_USERS)
        .order_by("-users")
        .first()
    )
    if not top:
        return []
    return [
        {
            "item": Item.objects.get(pk=top["item"]),
            "quantity": 1,
            "origin": Origin.AI_CROWD,
            "confidence": round(top["users"] / max(taggers, 1), 2),
        }
    ]


def _from_category(txn):
    if not txn.merchant_id:
        return []
    item = Item.objects.filter(category_id=txn.merchant.category_id, is_category_default=True).first()
    if not item:
        return []
    return [{"item": item, "quantity": 1, "origin": Origin.AI_CATEGORY, "confidence": 0.5}]


def suggest_items(txn):
    """Best guess at what was bought, from the most reliable source that has an answer.

    Order: own history at this payee, other users' confirmed tags at the shop, the
    shop category's default item. The LLM fallback (Origin.AI_LLM) arrives in Phase 4.
    """
    if txn.kind != "merchant":
        return []
    for source in (_from_own_history, _from_crowd, _from_category):
        found = source(txn)
        if found:
            return found
    return []


def auto_tag(txn):
    """Store the AI guess so an unanswered prompt still leaves a (lower-weight) tag."""
    if txn.kind != "merchant" or txn.items.exists():
        return []
    rows = [
        TransactionItem(
            transaction=txn, item=s["item"], quantity=s["quantity"], origin=s["origin"], confidence=s["confidence"]
        )
        for s in suggest_items(txn)
    ]
    return TransactionItem.objects.bulk_create(rows)


def should_prompt(txn) -> bool:
    """False once the shop's item is learned: every current tag is a guess from the user's
    own history and they have already confirmed that item here enough times."""
    active = list(txn.items.filter(rejected_at__isnull=True))
    if not active:
        return True
    if any(ti.origin == Origin.USER for ti in active):
        return False
    if any(ti.origin != Origin.AI_OWN_HISTORY for ti in active):
        return True
    confirmed = Counter(
        _confirmed()
        .filter(transaction__user=txn.user, transaction__payee=txn.payee, item__in=[ti.item_id for ti in active])
        .values_list("item_id", flat=True)
    )
    return any(confirmed[ti.item_id] < settings.AUTO_TAG_AFTER_CONFIRMATIONS for ti in active)


# --- user actions ----------------------------------------------------------------

def _require_taggable(txn):
    if txn.kind == "person":
        raise TaggingError("Payments to a person cannot be tagged.")


@transaction.atomic
def set_user_items(txn, entries, user):
    """Replace the payment's tags with what the user picked. entries: [{item|name, quantity}]."""
    _require_taggable(txn)
    chosen = {}
    for e in entries:
        item = e.get("item") or resolve_item(e["name"], user)
        chosen[item.id] = (item, e.get("quantity", 1))
    now = timezone.now()
    for ti in txn.items.all():
        if ti.item_id in chosen:
            continue
        if ti.origin == Origin.USER:
            ti.delete()
        elif ti.rejected_at is None:
            ti.rejected_at = now
            ti.save(update_fields=["rejected_at", "updated_at"])
    existing = {ti.item_id: ti for ti in txn.items.all()}
    for item, qty in chosen.values():
        ti = existing.get(item.id)
        if ti is None:
            TransactionItem.objects.create(transaction=txn, item=item, quantity=qty, origin=Origin.USER, confidence=1.0)
        else:
            _confirm(ti, quantity=qty)
    return list(txn.items.filter(rejected_at__isnull=True).select_related("item"))


def _confirm(ti, quantity=None):
    if ti.origin != Origin.USER:
        ti.ai_origin = ti.origin
    ti.origin, ti.confidence, ti.rejected_at = Origin.USER, 1.0, None
    if quantity is not None:
        ti.quantity = quantity
    ti.save()


@transaction.atomic
def confirm_items(txn):
    """The one-tap 'Yes': the AI guess was right."""
    _require_taggable(txn)
    active = list(txn.items.filter(rejected_at__isnull=True))
    if not active:
        raise TaggingError("Nothing to confirm: this payment has no suggested items.")
    for ti in active:
        if ti.origin != Origin.USER:
            _confirm(ti)
    return list(txn.items.filter(rejected_at__isnull=True).select_related("item"))
