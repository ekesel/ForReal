from django.conf import settings
from django.db import models
from django.db.models import Q


class Purpose(models.TextChoices):
    PRIVATE_ANALYTICS = "private_analytics", "C1 Private analytics"
    COMMUNITY_RANKINGS = "community_rankings", "C2 Community rankings"
    SHOW_NAME = "show_name", "C3 Show my name"
    LOCATION = "location", "C4 Location"
    MERCHANT_INSIGHTS = "merchant_insights", "C5 Merchant insights"


# A purpose can only be granted while its parent is granted, and is withdrawn with it.
REQUIRES = {
    Purpose.COMMUNITY_RANKINGS: Purpose.PRIVATE_ANALYTICS,
    Purpose.LOCATION: Purpose.PRIVATE_ANALYTICS,
    Purpose.SHOW_NAME: Purpose.COMMUNITY_RANKINGS,
    Purpose.MERCHANT_INSIGHTS: Purpose.COMMUNITY_RANKINGS,
}


class Consent(models.Model):
    """Append-only. Every grant or withdrawal is a new row; is_current marks the latest per purpose."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="consents")
    purpose = models.CharField(max_length=32, choices=Purpose.choices)
    granted = models.BooleanField()
    notice_version = models.CharField(max_length=20, help_text="Version of the notice text the user saw")
    is_current = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "purpose"], condition=Q(is_current=True), name="uniq_current_consent"
            )
        ]
        indexes = [
            models.Index(fields=["purpose", "user"], condition=Q(is_current=True, granted=True), name="consent_granted_idx")
        ]
