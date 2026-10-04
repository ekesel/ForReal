from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from .models import OtpChallenge


@shared_task
def purge_expired_otps():
    cutoff = timezone.now() - timedelta(days=1)
    deleted, _ = OtpChallenge.objects.filter(created_at__lt=cutoff).delete()
    return deleted
