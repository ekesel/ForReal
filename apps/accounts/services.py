from django.db import transaction

from .models import OtpChallenge


def export_user_data(user) -> dict:
    """Everything the server holds about a user, for the in-app export."""
    from apps.consents.models import Consent
    from apps.merchants.models import PayeeMerchantLink
    from apps.transactions.models import Transaction
    from apps.common.geo import point_to_dict

    txns = (
        Transaction.objects.filter(user=user)
        .select_related("payee", "merchant", "locality")
        .prefetch_related("items__item")
        .order_by("occurred_on", "created_at")
    )
    return {
        "user": {
            "id": str(user.id),
            "phone": user.phone,
            "display_name": user.display_name,
            "created_at": user.created_at.isoformat(),
        },
        "devices": list(user.devices.values("device_id", "platform", "app_version", "created_at")),
        "consent_history": list(
            Consent.objects.filter(user=user)
            .order_by("created_at")
            .values("purpose", "granted", "notice_version", "created_at")
        ),
        "payees": [
            {
                "payee": link.payee.display_name,
                "kind": link.kind,
                "merchant": link.merchant.name if link.merchant else None,
                "location": point_to_dict(link.location),
            }
            for link in PayeeMerchantLink.objects.filter(user=user).select_related("payee", "merchant")
        ],
        "transactions": [
            {
                "id": str(t.id),
                "payee": t.payee.display_name,
                "merchant": t.merchant.name if t.merchant else None,
                "kind": t.kind,
                "occurred_on": t.occurred_on.isoformat(),
                "day_part": t.day_part,
                "amount_band": t.amount_band,
                "sources": t.sources,
                "location": point_to_dict(t.location),
                "locality": t.locality.name if t.locality else None,
                "items": [
                    {"item": ti.item.name, "quantity": ti.quantity, "origin": ti.origin, "confidence": ti.confidence}
                    for ti in t.items.all()
                    if ti.rejected_at is None
                ],
            }
            for t in txns
        ],
    }


@transaction.atomic
def delete_account(user) -> None:
    """Hard delete. Transactions, tags, payee links, consents and devices cascade.

    Shops and catalogue items the user added stay, with their creator cleared.
    """
    OtpChallenge.objects.filter(phone=user.phone).delete()
    user.delete()
