import uuid

from django.conf import settings
from django.contrib.gis.db import models
from django.contrib.postgres.indexes import GinIndex
from django.db.models import Q


class Category(models.Model):
    slug = models.SlugField(unique=True)
    name = models.CharField(max_length=60)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Payee(models.Model):
    """The payee exactly as a bank message names it. Not unique to one shop or person:
    two different people can both appear as 'RAMESH KUMAR'."""

    display_name = models.CharField(max_length=140)
    normalized_name = models.CharField(max_length=140)
    # Empty for SMS. Reserved for the email lane, which carries the VPA.
    vpa = models.CharField(max_length=255, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["normalized_name", "vpa"], name="uniq_payee_name_vpa")]

    def __str__(self):
        return self.display_name


class Merchant(models.Model):
    """A real shop or business."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=120)
    normalized_name = models.CharField(max_length=120)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="merchants")
    location = models.PointField(geography=True, null=True, blank=True)
    locality = models.ForeignKey("geo.Locality", on_delete=models.SET_NULL, null=True, blank=True)
    # Online or multi-location brands (Swiggy, Rapido): matched by name alone, never by distance.
    is_online = models.BooleanField(default=False)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            GinIndex(fields=["normalized_name"], opclasses=["gin_trgm_ops"], name="merchant_name_trgm"),
            models.Index(fields=["locality", "category"]),
        ]

    def __str__(self):
        return self.name


class PayeeMerchantLink(models.Model):
    """One user's answer to 'shop or person, and which shop?' for one payee.
    Links from several users are what crowd matching counts."""

    class Kind(models.TextChoices):
        MERCHANT = "merchant"
        PERSON = "person"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="payee_links")
    payee = models.ForeignKey(Payee, on_delete=models.CASCADE, related_name="links")
    kind = models.CharField(max_length=10, choices=Kind.choices)
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, null=True, blank=True, related_name="links")
    # Where the user was when they confirmed it (coarse; only with location consent).
    location = models.PointField(geography=True, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "payee"], name="uniq_user_payee_link"),
            models.CheckConstraint(
                condition=Q(kind="merchant", merchant__isnull=False) | Q(kind="person", merchant__isnull=True),
                name="link_kind_matches_merchant",
            ),
        ]
        indexes = [models.Index(fields=["payee", "kind"])]
