from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.db import models
from django.db.models import Q


class Origin(models.TextChoices):
    USER = "user", "User confirmed or entered"
    AI_OWN_HISTORY = "ai_own_history", "AI: this user's history at the shop"
    AI_CROWD = "ai_crowd", "AI: other users' tags at the shop"
    AI_CATEGORY = "ai_category", "AI: category, amount and time"
    AI_LLM = "ai_llm", "AI: LLM guess"


class Item(models.Model):
    """Catalogue entry. 'chai', 'tea' and 'Tea' all resolve to one item through aliases."""

    name = models.CharField(max_length=60)
    slug = models.SlugField(max_length=70, unique=True)
    category = models.ForeignKey(
        "merchants.Category", on_delete=models.SET_NULL, null=True, blank=True, related_name="items"
    )
    # The item guessed for a shop of this category when nothing better is known.
    is_category_default = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False, help_text="False for items typed in by users")
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        indexes = [GinIndex(fields=["name"], opclasses=["gin_trgm_ops"], name="item_name_trgm")]
        constraints = [
            models.UniqueConstraint(
                fields=["category"], condition=Q(is_category_default=True), name="one_default_item_per_category"
            )
        ]

    def __str__(self):
        return self.name


class ItemAlias(models.Model):
    alias = models.CharField(max_length=60, unique=True, help_text="Lower case")
    item = models.ForeignKey(Item, on_delete=models.CASCADE, related_name="aliases")


class TransactionItem(models.Model):
    """One thing bought in one payment. A payment can have several."""

    transaction = models.ForeignKey("transactions.Transaction", on_delete=models.CASCADE, related_name="items")
    item = models.ForeignKey(Item, on_delete=models.PROTECT, related_name="tags")
    quantity = models.PositiveSmallIntegerField(default=1)
    origin = models.CharField(max_length=20, choices=Origin.choices)
    confidence = models.FloatField(default=1.0)
    # The AI origin a tag had before the user confirmed it. Kept to tune weights.
    ai_origin = models.CharField(max_length=20, choices=Origin.choices, blank=True)
    # Set when the user replaced an AI guess. Kept, inactive, to measure how often each origin is wrong.
    rejected_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["transaction", "item"], name="uniq_txn_item")]
        indexes = [models.Index(fields=["item", "origin"])]


class TagWeight(models.Model):
    """How much a tag of each origin counts at ranking time. Tuned without rewriting data."""

    origin = models.CharField(max_length=20, choices=Origin.choices, unique=True)
    weight = models.FloatField()

    def __str__(self):
        return f"{self.origin}: {self.weight}"
