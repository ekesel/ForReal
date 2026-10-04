import hashlib
import hmac

from django.conf import settings
from django.db import IntegrityError, transaction

from apps.common.geo import coarse_point
from apps.consents.models import Purpose
from apps.consents.services import has_consent
from apps.geo.models import Locality
from apps.geo.services import enqueue_locality
from apps.merchants.models import PayeeMerchantLink
from apps.merchants.services import crowd_suggestions, get_or_create_payee
from apps.tagging.services import auto_tag, should_prompt

from .models import Kind, Transaction


def hash_ref(ref: str) -> str:
    ref = (ref or "").strip()
    if not ref:
        return ""
    return hmac.new(settings.REF_HASH_PEPPER.encode(), ref.encode(), hashlib.sha256).hexdigest()


def ingest_batch(user, rows):
    """Store a batch of parsed payments. Safe to retry: each row is idempotent."""
    use_location = has_consent(user, Purpose.LOCATION)
    links = {}
    geocode_queued = set()  # coarse points already queued for geocoding in this batch
    results = []
    for row in rows:
        results.append(_ingest_one(user, row, use_location, links, geocode_queued))
    return results


def _existing(user, row, ref_hash):
    txn = Transaction.objects.filter(user=user, client_txn_id=row["client_txn_id"]).first()
    if txn:
        return txn, "duplicate"
    if ref_hash:
        txn = Transaction.objects.filter(user=user, ref_hash=ref_hash).first()
        if txn:
            # Same payment seen through another lane: merge instead of counting twice.
            if row["source"] not in txn.sources:
                txn.sources = [*txn.sources, row["source"]]
                txn.save(update_fields=["sources"])
            return txn, "merged"
    return None, None


def _ingest_one(user, row, use_location, links, geocode_queued):
    ref_hash = hash_ref(row.get("ref"))
    txn, status = _existing(user, row, ref_hash)
    if txn is None:
        payee = get_or_create_payee(row["payee_name"])
        if payee.id not in links:
            links[payee.id] = (
                PayeeMerchantLink.objects.filter(user=user, payee=payee).select_related("merchant").first()
            )
        link = links[payee.id]
        point = coarse_point(row.get("lat"), row.get("lng")) if use_location else None
        try:
            with transaction.atomic():
                txn = Transaction.objects.create(
                    user=user,
                    client_txn_id=row["client_txn_id"],
                    payee=payee,
                    merchant=link.merchant if link else None,
                    kind=link.kind if link else Kind.UNKNOWN,
                    occurred_on=row["occurred_on"],
                    day_part=row.get("day_part") or "",
                    amount_band=row["amount_band"],
                    sources=[row["source"]],
                    ref_hash=ref_hash,
                    location=point,
                    locality=Locality.objects.for_point(point),
                )
                status = "created"
                auto_tag(txn)
        except IntegrityError:
            # A concurrent upload of the same payment won the race.
            txn, status = _existing(user, row, ref_hash)
            if txn is None:
                raise
        else:
            # No known locality here yet: resolve it in the background, never in the request.
            enqueue_locality(txn, geocode_queued)
    return {"status": status, "transaction": txn}


@transaction.atomic
def attach_location(txn, lat, lng):
    """Give a payment the location it was ingested without (the app only has a fix in
    the foreground). The first location wins: a payment that already has one is left alone."""
    txn = Transaction.objects.select_for_update().get(pk=txn.pk)
    if txn.location is None:
        txn.location = coarse_point(lat, lng)
        txn.locality = Locality.objects.for_point(txn.location)
        txn.save(update_fields=["location", "locality"])
        # Same as ingest: an unknown area is named in the background, after the commit.
        enqueue_locality(txn)
    return txn


def payee_prompt(txn):
    """What the app should ask about this payment, if anything."""
    if txn.kind == Kind.UNKNOWN:
        return {"ask": "payee", "crowd": crowd_suggestions(txn.payee, txn.location, exclude_user=txn.user)}
    if txn.kind == Kind.MERCHANT and should_prompt(txn):
        return {"ask": "items", "crowd": []}
    return {"ask": None, "crowd": []}
