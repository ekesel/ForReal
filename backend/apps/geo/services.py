import logging
from decimal import Decimal

from django.conf import settings
from django.db import IntegrityError, transaction

from .geocoding import get_geocoder
from .models import GeocodeCell, Locality

log = logging.getLogger(__name__)


def cell_key(point):
    """The coarse point as the (lat, lng) decimals that key a GeocodeCell."""
    d = settings.LOCATION_DECIMALS
    return Decimal(str(round(point.y, d))), Decimal(str(round(point.x, d)))


def _cell_for(lat, lng):
    return GeocodeCell.objects.select_related("locality").filter(lat=lat, lng=lng).first()


def _locality_for(result, point):
    name, city = result.name[:120], result.city[:80]
    try:
        with transaction.atomic():
            # An existing row keeps its centre; only a new one is centred on this point.
            locality, _ = Locality.objects.get_or_create(
                name=name, city=city, defaults={"state": result.state[:80], "centre": point}
            )
    except IntegrityError:
        locality = Locality.objects.get(name=name, city=city)
    return locality


def resolve_locality(point):
    """The locality for a coarse point, reverse-geocoding it at most once.

    Raises GeocoderUnavailable when the provider cannot answer right now; nothing is
    cached in that case, so a later call tries again.
    """
    if point is None:
        return None
    locality = Locality.objects.for_point(point)
    if locality:
        return locality
    lat, lng = cell_key(point)
    cell = _cell_for(lat, lng)
    if cell and cell.status == GeocodeCell.Status.RESOLVED and cell.locality_id is None:
        # Its locality was deleted since: the cached answer is gone, so look it up again.
        cell.delete()
        cell = None
    if cell:
        return cell.locality
    geocoder = get_geocoder()
    if not geocoder.enabled:
        return None
    result = geocoder.reverse(float(lat), float(lng))
    locality = _locality_for(result, point) if result else None
    try:
        with transaction.atomic():
            GeocodeCell.objects.create(
                lat=lat,
                lng=lng,
                locality=locality,
                status=GeocodeCell.Status.RESOLVED if locality else GeocodeCell.Status.NO_RESULT,
                provider=result.provider if result else geocoder.provider,
            )
    except IntegrityError:
        # Another worker resolved the same cell first: its answer stands.
        cell = _cell_for(lat, lng)
        return cell.locality if cell else locality
    return locality


def enqueue_locality(obj, seen=None):
    """Queue background locality assignment for a row that has a location but no locality.

    The task is sent only after the surrounding transaction commits, so it never runs
    before the row exists, and the caller never waits on the geocoder. Pass the same
    `seen` set for a whole batch to queue each coarse point only once.
    """
    if obj.location is None or obj.locality_id is not None:
        return
    if not get_geocoder().enabled:
        return
    key = cell_key(obj.location)
    if seen is not None:
        if key in seen:
            return
        seen.add(key)
    from .tasks import assign_locality

    label, pk = obj._meta.label, str(obj.pk)
    # robust: a broker outage is logged, not turned into a failed request.
    transaction.on_commit(lambda: assign_locality.delay(label, pk), robust=True)
