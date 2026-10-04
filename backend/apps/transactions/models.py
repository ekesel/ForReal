import uuid

from django.conf import settings
from django.contrib.gis.db import models
from django.contrib.postgres.fields import ArrayField
from django.db.models import Q


class Source(models.TextChoices):
    SMS = "sms"
    EMAIL = "email"
    SHORTCUT = "shortcut"
    STATEMENT = "statement"


class AmountBand(models.TextChoices):
    LT_50 = "lt_50", "Under ₹50"
    B50_200 = "50_200", "₹50 to 200"
    B200_500 = "200_500", "₹200 to 500"
    GT_500 = "gt_500", "Above ₹500"


class DayPart(models.TextChoices):
    MORNING = "morning"
    AFTERNOON = "afternoon"
    EVENING = "evening"
    NIGHT = "night"


class Kind(models.TextChoices):
    UNKNOWN = "unknown"  # payee not yet labelled; private
    MERCHANT = "merchant"
    PERSON = "person"  # always private


class TransactionQuerySet(models.QuerySet):
    def shareable(self):
        """The only transactions that may ever feed community data: paid to a confirmed
        shop, by a user who currently holds the community consent."""
        from apps.consents.models import Purpose
        from apps.consents.services import users_with_consent

        return self.filter(
            kind=Kind.MERCHANT,
            merchant__isnull=False,
            user__in=users_with_consent(Purpose.COMMUNITY_RANKINGS),
        )


class Transaction(models.Model):
    """One payment. Holds no raw message text, no exact amount and no account details."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="transactions")
    # Idempotency key generated on the device.
    client_txn_id = models.UUIDField()
    payee = models.ForeignKey("merchants.Payee", on_delete=models.PROTECT, related_name="transactions")
    merchant = models.ForeignKey(
        "merchants.Merchant", on_delete=models.SET_NULL, null=True, blank=True, related_name="transactions"
    )
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.UNKNOWN)
    occurred_on = models.DateField()
    day_part = models.CharField(max_length=10, choices=DayPart.choices, blank=True)
    amount_band = models.CharField(max_length=10, choices=AmountBand.choices)
    # Every capture lane that reported this payment.
    sources = ArrayField(models.CharField(max_length=10, choices=Source.choices), default=list)
    # HMAC of the UPI reference; used only to merge the same payment across lanes.
    ref_hash = models.CharField(max_length=64, blank=True, default="")
    location = models.PointField(geography=True, null=True, blank=True)
    locality = models.ForeignKey("geo.Locality", on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = TransactionQuerySet.as_manager()

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "client_txn_id"], name="uniq_user_client_txn"),
            models.UniqueConstraint(fields=["user", "ref_hash"], condition=~Q(ref_hash=""), name="uniq_user_ref"),
        ]
        indexes = [
            models.Index(fields=["user", "-occurred_on"]),
            models.Index(fields=["user", "payee"]),
            # Payer counts and repeat rate per merchant (Phase 4 rankings).
            models.Index(fields=["merchant", "user"], condition=Q(kind="merchant"), name="txn_merchant_payer_idx"),
            models.Index(fields=["locality", "merchant"], condition=Q(kind="merchant"), name="txn_locality_merchant_idx"),
        ]
