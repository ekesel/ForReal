from celery import shared_task
from django.apps import apps
from django.contrib.gis.measure import D

from .geocoding import GeocoderUnavailable
from .services import resolve_locality

MODELS = ("transactions.Transaction", "merchants.Merchant")


def rows_at(model, point):
    """Rows of a model stored at this coarse point that still have no locality.

    Coarse points are about 110 m apart, so "within a metre" means "the same point".
    """
    return model.objects.filter(location__dwithin=(point, D(m=1)), locality__isnull=True)


@shared_task(
    autoretry_for=(GeocoderUnavailable,),
    retry_backoff=True,
    retry_backoff_max=600,
    retry_jitter=True,
    max_retries=5,
)
def assign_locality(model_label, pk):
    """Resolve the locality of one transaction or merchant and of every row sharing its point."""
    if model_label not in MODELS:
        raise ValueError(f"assign_locality does not handle {model_label}")
    model = apps.get_model(model_label)
    row = model.objects.filter(pk=pk).only("location", "locality").first()
    if row is None or row.location is None or row.locality_id is not None:
        return 0
    locality = resolve_locality(row.location)
    if locality is None:
        return 0
    # Conditional updates touch only the locality column, and skip any row whose location
    # was erased (consent withdrawn) while the geocoder was answering.
    updated = model.objects.filter(pk=pk, location__isnull=False, locality__isnull=True).update(locality=locality)
    for label in MODELS:
        updated += rows_at(apps.get_model(label), row.location).update(locality=locality)
    return updated
