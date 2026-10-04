"""Reverse geocoding behind a swappable adapter.

Everything provider-specific lives in this module. Callers use `get_geocoder()` and
the `Geocoder` contract only; they never learn which provider answered beyond the
opaque `provider` label stored for cache invalidation.

Only a latitude and a longitude are ever sent to a provider. Never a user id, a
phone number or anything else.
"""
import logging
import threading
import time
from dataclasses import dataclass
from typing import Protocol

import redis
import requests
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.module_loading import import_string

log = logging.getLogger(__name__)


class GeocoderUnavailable(Exception):
    """The provider could not answer right now (network error, timeout, 429, 5xx). Retry later."""


@dataclass(frozen=True)
class GeocodeResult:
    name: str
    city: str
    state: str
    provider: str


class Geocoder(Protocol):
    """Contract every adapter implements.

    `reverse` returns None when the provider has no usable area name for the point and
    raises GeocoderUnavailable for anything worth retrying. `provider` is a short label
    recorded with each cached answer. `enabled` is False for adapters that never look
    anything up, so their non-answers are not cached.
    """

    provider: str
    enabled: bool

    def reverse(self, lat: float, lng: float) -> GeocodeResult | None: ...


def get_geocoder() -> Geocoder:
    return import_string(settings.GEOCODER_BACKEND)()


class NullGeocoder:
    """Geocoding switched off: never calls anything, never finds anything."""

    provider = "null"
    enabled = False

    def reverse(self, lat: float, lng: float) -> GeocodeResult | None:
        return None


# --- Rate limiting -----------------------------------------------------------
# The public Nominatim service allows at most one request per second in total, so
# the limit is shared by all workers through Redis. The margin absorbs clock skew.
MIN_INTERVAL_S = 1.1
MAX_QUEUE_WAIT_S = 30
_RATE_KEY = "forreal:geocoder:nominatim:slot"


class _LocalLimiter:
    """Process-wide spacing of calls. Used only when Redis cannot be reached."""

    def __init__(self, interval):
        self._interval = interval
        self._lock = threading.Lock()
        self._next = None

    def wait(self):
        with self._lock:
            now = time.monotonic()
            slot = now if self._next is None else max(now, self._next)
            self._next = slot + self._interval
        if slot > now:
            time.sleep(slot - now)


_local_limiter = _LocalLimiter(MIN_INTERVAL_S)
_redis = None


def _redis_client():
    global _redis
    if _redis is None:
        _redis = redis.Redis.from_url(settings.REDIS_URL, socket_connect_timeout=1, socket_timeout=1)
    return _redis


def _redis_wait():
    """Take the shared one-per-interval slot, waiting for it if another worker holds it."""
    client = _redis_client()
    deadline = time.monotonic() + MAX_QUEUE_WAIT_S
    while not client.set(_RATE_KEY, "1", nx=True, px=int(MIN_INTERVAL_S * 1000)):
        if time.monotonic() >= deadline:
            raise GeocoderUnavailable("Too many geocoding requests are queued.")
        remaining_ms = client.pttl(_RATE_KEY)
        if remaining_ms < 0:
            # Key just expired, or has no expiry (set by hand): wait a full interval, never spin.
            remaining_ms = int(MIN_INTERVAL_S * 1000)
        time.sleep(max(remaining_ms, 10) / 1000)


def _rate_limit():
    try:
        _redis_wait()
    except redis.RedisError:
        log.warning("Redis unavailable for the geocoder rate limit; limiting within this process only.")
        _local_limiter.wait()


# --- Adapters ----------------------------------------------------------------
def _first(address, keys):
    for key in keys:
        value = (address.get(key) or "").strip()
        if value:
            return value
    return ""


class NominatimGeocoder:
    """OpenStreetMap Nominatim. Data © OpenStreetMap contributors (ODbL).

    Follows the public usage policy: an identifying User-Agent and at most one
    request per second across all workers.
    """

    provider = "nominatim"
    enabled = True
    timeout_s = 5
    name_keys = ("suburb", "neighbourhood", "quarter", "residential", "city_district", "village", "town")
    city_keys = ("city", "town", "municipality", "county", "state_district")

    def reverse(self, lat: float, lng: float) -> GeocodeResult | None:
        user_agent = (settings.NOMINATIM_USER_AGENT or "").strip()
        if not user_agent:
            raise ImproperlyConfigured(
                "NOMINATIM_USER_AGENT must identify this application, e.g. 'ForReal/0.1 (you@example.com)'."
            )
        _rate_limit()
        try:
            response = requests.get(
                f"{settings.NOMINATIM_BASE_URL.rstrip('/')}/reverse",
                params={
                    "format": "jsonv2",
                    "lat": lat,
                    "lon": lng,
                    "zoom": 16,
                    "addressdetails": 1,
                    "accept-language": "en",
                },
                headers={"User-Agent": user_agent},
                timeout=self.timeout_s,
            )
        except requests.RequestException as exc:
            raise GeocoderUnavailable(f"Nominatim request failed: {type(exc).__name__}") from exc
        if response.status_code != 200:
            # 429 and 5xx are transient. Other statuses (403 when blocked, for example) say
            # nothing about the point itself, so they must not be cached as "no result".
            raise GeocoderUnavailable(f"Nominatim answered HTTP {response.status_code}")
        try:
            body = response.json()
        except ValueError as exc:
            raise GeocoderUnavailable("Nominatim returned a body that is not JSON") from exc
        address = body.get("address") if isinstance(body, dict) else None
        if not isinstance(address, dict):
            return None  # e.g. {"error": "Unable to geocode"} in the middle of the sea
        name = _first(address, self.name_keys)
        if not name:
            # Never fall back to the city: a locality named after its whole city is useless.
            return None
        return GeocodeResult(
            name=name,
            city=_first(address, self.city_keys),
            state=_first(address, ("state",)),
            provider=self.provider,
        )


class GoogleGeocoder:
    """Google Geocoding API reverse lookup. Not implemented yet.

    Mapping to implement:
      * GET https://maps.googleapis.com/maps/api/geocode/json with latlng="<lat>,<lng>",
        language=en and key=settings.GOOGLE_MAPS_API_KEY.
      * name: the first address component found of type sublocality_level_1, then
        sublocality, then neighborhood. No such component means return None; never
        fall back to the city.
      * city: the component of type locality.
      * state: the component of type administrative_area_level_1.
      * OVER_QUERY_LIMIT, UNKNOWN_ERROR, network errors, timeouts, 429 and 5xx raise
        GeocoderUnavailable. ZERO_RESULTS returns None.
      * Send nothing but the coordinate.
    """

    provider = "google"
    enabled = True

    def reverse(self, lat: float, lng: float) -> GeocodeResult | None:
        raise NotImplementedError("GoogleGeocoder is a placeholder; see its docstring for the mapping.")
