from django.conf import settings
from django.contrib.gis.measure import D
from django.contrib.postgres.search import TrigramSimilarity
from django.db import transaction
from django.db.models import Count, Q

from apps.common.text import normalize_name
from apps.consents.models import Purpose
from apps.consents.services import users_with_consent
from apps.geo.models import Locality

from .models import Merchant, Payee, PayeeMerchantLink


def get_or_create_payee(name: str) -> Payee:
    norm = normalize_name(name)
    payee, _ = Payee.objects.get_or_create(normalized_name=norm, vpa="", defaults={"display_name": name.strip()[:140]})
    return payee


def crowd_suggestions(payee, point, exclude_user=None):
    """Shops that enough other users have confirmed this payee to be, near this point.

    Only users with the community consent contribute, and nothing is returned below
    the confirmation threshold, so one person's answer is never revealed to another.
    """
    links = PayeeMerchantLink.objects.filter(
        payee=payee,
        kind=PayeeMerchantLink.Kind.MERCHANT,
        user__in=users_with_consent(Purpose.COMMUNITY_RANKINGS),
    )
    if exclude_user is not None:
        links = links.exclude(user=exclude_user)
    near = Q(merchant__is_online=True)
    if point is not None:
        near |= Q(location__dwithin=(point, D(m=settings.CROWD_MATCH_RADIUS_M)))
    rows = (
        links.filter(near)
        .values("merchant")
        .annotate(confirmations=Count("user", distinct=True))
        .filter(confirmations__gte=settings.CROWD_MIN_CONFIRMATIONS)
        .order_by("-confirmations")[:5]
    )
    merchants = Merchant.objects.select_related("category").in_bulk([r["merchant"] for r in rows])
    return [merchants[r["merchant"]] for r in rows]


def search_merchants(query, point=None, limit=20):
    qs = (
        Merchant.objects.select_related("category")
        .annotate(sim=TrigramSimilarity("normalized_name", normalize_name(query)))
        .filter(Q(sim__gte=0.2) | Q(normalized_name__contains=normalize_name(query)))
    )
    if point is not None:
        qs = qs.filter(Q(is_online=True) | Q(location__dwithin=(point, D(km=5))))
    return list(qs.order_by("-sim", "name")[:limit])


def find_or_create_merchant(user, name, category, point=None, is_online=False) -> Merchant:
    """Reuse an existing shop with a similar name in the same spot instead of creating a duplicate."""
    norm = normalize_name(name)
    candidates = Merchant.objects.annotate(sim=TrigramSimilarity("normalized_name", norm)).filter(
        sim__gte=settings.MERCHANT_DEDUP_SIMILARITY
    )
    if is_online:
        candidates = candidates.filter(is_online=True)
    elif point is not None:
        candidates = candidates.filter(
            is_online=False, location__dwithin=(point, D(m=settings.MERCHANT_DEDUP_RADIUS_M))
        )
    else:
        candidates = candidates.none()
    existing = candidates.order_by("-sim").first()
    if existing:
        return existing
    return Merchant.objects.create(
        name=name.strip()[:120],
        normalized_name=norm[:120],
        category=category,
        location=None if is_online else point,
        locality=None if is_online else Locality.objects.for_point(point),
        is_online=is_online,
        created_by=user,
    )


@transaction.atomic
def resolve_payee(user, payee, kind, merchant=None, point=None) -> PayeeMerchantLink:
    """Save the user's answer and apply it to all their payments to this payee."""
    from apps.tagging.models import TransactionItem
    from apps.tagging.services import auto_tag
    from apps.transactions.models import Transaction

    previous = PayeeMerchantLink.objects.filter(user=user, payee=payee).first()
    link, _ = PayeeMerchantLink.objects.update_or_create(
        user=user, payee=payee, defaults={"kind": kind, "merchant": merchant, "location": point}
    )
    txns = Transaction.objects.filter(user=user, payee=payee)
    txns.update(kind=kind, merchant=merchant)
    tags = TransactionItem.objects.filter(transaction__in=txns)
    if kind == PayeeMerchantLink.Kind.PERSON:
        # Payments to people carry no item tags and never enter shared data.
        tags.delete()
    else:
        if previous and previous.merchant_id != merchant.id:
            # Corrected to a different shop: guesses made for the old one no longer apply.
            tags.exclude(origin="user").delete()
        for txn in txns.select_related("merchant__category", "payee", "user"):
            auto_tag(txn)
    return link
