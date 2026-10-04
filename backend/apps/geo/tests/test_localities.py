import logging
from decimal import Decimal
from io import StringIO
from unittest import mock

import redis
import requests
from celery import current_app
from django.contrib.gis.geos import Point
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.test import SimpleTestCase, override_settings

from apps.common.geo import coarse_point
from apps.consents.services import set_consent
from apps.common.testing import FAR, HERE, NEARBY, ApiTestCase
from apps.geo import geocoding
from apps.geo.geocoding import (
    GeocodeResult,
    GeocoderUnavailable,
    GoogleGeocoder,
    NominatimGeocoder,
    NullGeocoder,
)
from apps.geo.models import GeocodeCell, Locality
from apps.geo.services import resolve_locality
from apps.merchants.models import Merchant
from apps.transactions.models import Transaction

FAKE = "apps.geo.tests.test_localities.FakeGeocoder"
NULL = "apps.geo.geocoding.NullGeocoder"


class FakeGeocoder:
    """Counts calls and answers from class-level state, so tests can steer it."""

    provider = "fake"
    enabled = True
    calls = []
    answer = ("Sector 62", "Noida", "Uttar Pradesh")  # None means "no usable name"
    error = None
    before_answer = None  # hook run inside reverse(), to simulate a concurrent worker

    @classmethod
    def reset(cls):
        cls.calls = []
        cls.answer = ("Sector 62", "Noida", "Uttar Pradesh")
        cls.error = None
        cls.before_answer = None

    def reverse(self, lat, lng):
        FakeGeocoder.calls.append((lat, lng))
        if FakeGeocoder.error:
            raise FakeGeocoder.error
        if FakeGeocoder.before_answer:
            FakeGeocoder.before_answer()
        if FakeGeocoder.answer is None:
            return None
        return GeocodeResult(*FakeGeocoder.answer, provider=self.provider)


class EagerCeleryMixin:
    def setUp(self):
        super().setUp()
        FakeGeocoder.reset()
        # The Celery app read its config at start-up, so set the flag on it as well.
        previous = current_app.conf.task_always_eager
        current_app.conf.task_always_eager = True
        self.addCleanup(setattr, current_app.conf, "task_always_eager", previous)
        # Keep per-task result lines and expected retry tracebacks out of the test output.
        trace_log = logging.getLogger("celery.app.trace")
        self.addCleanup(trace_log.setLevel, trace_log.level)
        trace_log.setLevel(logging.CRITICAL + 1)

    def pay_committed(self, user, payee="RAMESH KUMAR", **over):
        """Ingest one payment and run what was queued for after the commit."""
        with self.captureOnCommitCallbacks(execute=True):
            return self.pay(user, payee, **over)


@override_settings(GEOCODER_BACKEND=FAKE, CELERY_TASK_ALWAYS_EAGER=True)
class LocalityResolutionTests(EagerCeleryMixin, ApiTestCase):
    def test_first_payment_in_a_new_area_creates_the_locality(self):
        user = self.make_user()
        self.pay_committed(user)
        locality = Locality.objects.get()
        self.assertEqual((locality.name, locality.city, locality.state), ("Sector 62", "Noida", "Uttar Pradesh"))
        self.assertEqual((locality.centre.y, locality.centre.x), (28.628, 77.365))
        self.assertEqual(Transaction.objects.get().locality, locality)
        cell = GeocodeCell.objects.get()
        self.assertEqual((cell.lat, cell.lng), (Decimal("28.628"), Decimal("77.365")))
        self.assertEqual((cell.status, cell.provider, cell.locality), ("resolved", "fake", locality))

    def test_only_the_rounded_coordinate_reaches_the_geocoder(self):
        self.pay_committed(self.make_user(), lat=28.62804321, lng=77.36491234)
        self.assertEqual(FakeGeocoder.calls, [(28.628, 77.365)])

    def test_ingest_response_does_not_wait_for_the_geocoder(self):
        user = self.make_user()
        with self.captureOnCommitCallbacks() as callbacks:
            self.pay(user)
        self.assertEqual(len(callbacks), 1)
        self.assertEqual(FakeGeocoder.calls, [])
        self.assertIsNone(Transaction.objects.get().locality)

    def test_second_payment_at_the_same_point_makes_no_call(self):
        user = self.make_user()
        self.pay_committed(user)
        result = self.pay_committed(user)
        self.assertEqual(len(FakeGeocoder.calls), 1)
        self.assertEqual(Transaction.objects.filter(locality=Locality.objects.get()).count(), 2)
        # The synchronous lookup already finds it, so the response carries it straight away.
        self.assertEqual(Transaction.objects.get(pk=result["transaction"]["id"]).locality, Locality.objects.get())

    def test_one_batch_queues_each_coarse_point_once(self):
        user = self.make_user()
        rows = [self.row(), self.row(), self.row(**FAR)]
        with self.captureOnCommitCallbacks(execute=True) as callbacks:
            self.ingest(self.client_for(user), *rows)
        self.assertEqual(len(callbacks), 2)
        self.assertEqual(len(FakeGeocoder.calls), 2)
        self.assertFalse(Transaction.objects.filter(locality__isnull=True).exists())

    def test_nearby_point_reuses_the_existing_locality(self):
        user = self.make_user()
        self.pay_committed(user)
        self.pay_committed(user, **NEARBY)
        self.assertEqual(len(FakeGeocoder.calls), 1)
        self.assertEqual(Locality.objects.count(), 1)
        self.assertEqual(GeocodeCell.objects.count(), 1)
        self.assertEqual(Transaction.objects.filter(locality=Locality.objects.get()).count(), 2)

    def test_no_result_is_remembered_and_not_retried(self):
        FakeGeocoder.answer = None
        user = self.make_user()
        self.pay_committed(user)
        cell = GeocodeCell.objects.get()
        self.assertEqual((cell.status, cell.provider, cell.locality), ("no_result", "fake", None))
        self.pay_committed(user)
        self.assertEqual(len(FakeGeocoder.calls), 1)
        self.assertEqual(GeocodeCell.objects.count(), 1)
        self.assertFalse(Locality.objects.exists())
        self.assertFalse(Transaction.objects.filter(locality__isnull=False).exists())

    def test_two_points_with_the_same_name_and_city_share_one_locality(self):
        user = self.make_user()
        self.pay_committed(user)
        self.pay_committed(user, **FAR)
        self.assertEqual(len(FakeGeocoder.calls), 2)
        locality = Locality.objects.get()
        # The existing row's centre stays where the first point put it.
        self.assertEqual((locality.centre.y, locality.centre.x), (28.628, 77.365))
        self.assertEqual(GeocodeCell.objects.filter(locality=locality).count(), 2)
        self.assertEqual(Transaction.objects.filter(locality=locality).count(), 2)

    def test_user_without_location_consent_triggers_no_geocoding(self):
        user = self.make_user(consents=["private_analytics"])
        result = self.pay_committed(user)
        with self.captureOnCommitCallbacks(execute=True):
            self.resolve_new(user, result["transaction"]["payee"]["id"])
        self.assertEqual(FakeGeocoder.calls, [])
        txn = Transaction.objects.get()
        self.assertIsNone(txn.location)
        self.assertIsNone(txn.locality)
        self.assertIsNone(Merchant.objects.get().locality)
        self.assertFalse(GeocodeCell.objects.exists())
        self.assertFalse(Locality.objects.exists())

    def test_new_merchant_from_payee_resolve_gets_its_locality(self):
        user = self.make_user()
        result = self.pay_committed(user, lat=None, lng=None)
        self.assertEqual(FakeGeocoder.calls, [])
        with self.captureOnCommitCallbacks(execute=True):
            self.resolve_new(user, result["transaction"]["payee"]["id"])
        self.assertEqual(len(FakeGeocoder.calls), 1)
        self.assertEqual(Merchant.objects.get().locality, Locality.objects.get())

    def test_resolving_a_cell_backfills_other_rows_at_the_same_point(self):
        user = self.make_user()
        with override_settings(GEOCODER_BACKEND=NULL):
            first = self.pay_committed(user)
            self.pay_committed(user, **FAR)
            self.resolve_new(user, first["transaction"]["payee"]["id"])
        self.assertIsNone(Merchant.objects.get().locality)
        self.pay_committed(user, "RINA DEVI")
        locality = Locality.objects.get()
        self.assertEqual(Transaction.objects.filter(locality=locality).count(), 2)
        self.assertEqual(Merchant.objects.get().locality, locality)
        # The row at the other point is untouched.
        self.assertEqual(Transaction.objects.filter(locality__isnull=True).count(), 1)

    def test_null_geocoder_creates_nothing_and_breaks_nothing(self):
        user = self.make_user()
        with override_settings(GEOCODER_BACKEND=NULL):
            result = self.pay_committed(user)
            with self.captureOnCommitCallbacks(execute=True):
                self.resolve_new(user, result["transaction"]["payee"]["id"])
            self.assertIsNone(resolve_locality(coarse_point(**HERE)))
        self.assertIsNone(NullGeocoder().reverse(28.628, 77.365))
        self.assertEqual(FakeGeocoder.calls, [])
        self.assertFalse(Locality.objects.exists())
        self.assertFalse(GeocodeCell.objects.exists())
        self.assertIsNone(Transaction.objects.get().locality)
        self.assertIsNone(Merchant.objects.get().locality)

    def test_unavailable_geocoder_leaves_no_cell_so_a_later_attempt_succeeds(self):
        FakeGeocoder.error = GeocoderUnavailable("down")
        user = self.make_user()
        self.pay_committed(user)
        self.assertTrue(FakeGeocoder.calls)
        self.assertFalse(GeocodeCell.objects.exists())
        self.assertFalse(Locality.objects.exists())
        self.assertIsNone(Transaction.objects.get().locality)

        FakeGeocoder.reset()
        self.pay_committed(user)
        self.assertEqual(len(FakeGeocoder.calls), 1)
        self.assertEqual(Transaction.objects.filter(locality=Locality.objects.get()).count(), 2)

    def test_losing_a_race_for_the_same_cell_uses_the_winners_answer(self):
        point = coarse_point(**HERE)

        def another_worker_wins():
            winner = Locality.objects.create(name="Sector 62", city="Noida", centre=Point(77.5, 28.9, srid=4326))
            GeocodeCell.objects.create(
                lat=Decimal("28.628"), lng=Decimal("77.365"), locality=winner, status="resolved", provider="fake"
            )

        FakeGeocoder.before_answer = another_worker_wins
        locality = resolve_locality(point)
        self.assertEqual(Locality.objects.get(), locality)
        self.assertEqual(GeocodeCell.objects.get().locality, locality)
        # The existing locality's centre was not moved.
        self.assertEqual((locality.centre.y, locality.centre.x), (28.9, 77.5))

    def test_consent_withdrawn_while_geocoding_leaves_the_payment_without_locality(self):
        user = self.make_user()
        # The withdrawal lands while the provider is still answering.
        FakeGeocoder.before_answer = lambda: set_consent(user, "location", False, "v1")
        self.pay_committed(user)
        self.assertEqual(len(FakeGeocoder.calls), 1)
        txn = Transaction.objects.get()
        self.assertIsNone(txn.location)
        self.assertIsNone(txn.locality)

    def test_withdrawing_location_consent_keeps_cells_and_localities(self):
        user = self.make_user()
        self.pay_committed(user)
        res = self.client_for(user).post(
            "/api/v1/consents/", {"purpose": "location", "granted": False, "notice_version": "v1"}, format="json"
        )
        self.assertEqual(res.status_code, 200, res.data)
        txn = Transaction.objects.get()
        self.assertIsNone(txn.location)
        self.assertIsNone(txn.locality)
        self.assertEqual(Locality.objects.count(), 1)
        self.assertEqual(GeocodeCell.objects.count(), 1)


@override_settings(CELERY_TASK_ALWAYS_EAGER=True)
class BackfillCommandTests(EagerCeleryMixin, ApiTestCase):
    def test_backfill_fills_rows_ingested_while_geocoding_was_off(self):
        user = self.make_user()
        first = self.pay_committed(user)
        self.pay_committed(user)
        self.resolve_new(user, first["transaction"]["payee"]["id"])
        self.assertFalse(Transaction.objects.filter(locality__isnull=False).exists())

        out = StringIO()
        with override_settings(GEOCODER_BACKEND=FAKE):
            call_command("backfill_localities", stdout=out)
        self.assertIn("3 rows", out.getvalue())
        self.assertEqual(len(FakeGeocoder.calls), 1)
        locality = Locality.objects.get()
        self.assertEqual(Transaction.objects.filter(locality=locality).count(), 2)
        self.assertEqual(Merchant.objects.get().locality, locality)

    def test_regeocode_provider_removes_only_that_providers_no_result_cells(self):
        locality = Locality.objects.create(name="Sector 62", city="Noida", centre=coarse_point(**HERE))
        cells = [
            ("1.001", "nominatim", "no_result", None),
            ("1.002", "nominatim", "resolved", locality),
            ("1.003", "google", "no_result", None),
        ]
        for lat, provider, status, loc in cells:
            GeocodeCell.objects.create(lat=Decimal(lat), lng=Decimal("2"), provider=provider, status=status, locality=loc)

        out = StringIO()
        call_command("backfill_localities", "--regeocode-provider", "nominatim", stdout=out)
        self.assertIn("Removed 1 ", out.getvalue())
        self.assertEqual(
            set(GeocodeCell.objects.values_list("provider", "status")),
            {("nominatim", "resolved"), ("google", "no_result")},
        )
        self.assertEqual(Locality.objects.get(), locality)


# A reverse lookup for 28.628, 77.365 (Sector 62, Noida) in Nominatim's jsonv2 format.
NOIDA_SECTOR_62 = {
    "place_id": 231504820,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright",
    "osm_type": "way",
    "osm_id": 368012345,
    "lat": "28.6279531",
    "lon": "77.3650128",
    "category": "highway",
    "type": "residential",
    "place_rank": 26,
    "importance": 0.0533,
    "addresstype": "road",
    "name": "",
    "display_name": "Sector 62, Noida, Dadri, Gautam Buddha Nagar, Uttar Pradesh, 201309, India",
    "address": {
        "suburb": "Sector 62",
        "city": "Noida",
        "county": "Dadri",
        "state_district": "Gautam Buddha Nagar",
        "state": "Uttar Pradesh",
        "ISO3166-2-lvl4": "IN-UP",
        "postcode": "201309",
        "country": "India",
        "country_code": "in",
    },
    "boundingbox": ["28.6271", "28.6288", "77.3641", "77.3659"],
}


def http_response(status=200, body=None):
    response = mock.Mock(status_code=status)
    response.json.return_value = body if body is not None else {}
    return response


@override_settings(
    NOMINATIM_BASE_URL="https://nominatim.example.test/",
    NOMINATIM_USER_AGENT="ForReal-tests/0.1 (dev@example.test)",
)
class NominatimGeocoderTests(SimpleTestCase):
    def setUp(self):
        limiter = mock.patch.object(geocoding, "_rate_limit")
        self.rate_limit = limiter.start()
        self.addCleanup(limiter.stop)

    def reverse(self, response=None, side_effect=None):
        with mock.patch("requests.get", return_value=response, side_effect=side_effect) as get:
            self.get = get
            return NominatimGeocoder().reverse(28.628, 77.365)

    def test_parses_a_noida_sector_62_response(self):
        result = self.reverse(http_response(body=NOIDA_SECTOR_62))
        self.assertEqual(
            result, GeocodeResult(name="Sector 62", city="Noida", state="Uttar Pradesh", provider="nominatim")
        )

    def test_request_follows_the_contract_and_sends_only_the_coordinate(self):
        self.reverse(http_response(body=NOIDA_SECTOR_62))
        (url,), kwargs = self.get.call_args
        self.assertEqual(url, "https://nominatim.example.test/reverse")
        self.assertEqual(
            kwargs["params"],
            {"format": "jsonv2", "lat": 28.628, "lon": 77.365, "zoom": 16, "addressdetails": 1, "accept-language": "en"},
        )
        self.assertEqual(kwargs["headers"], {"User-Agent": "ForReal-tests/0.1 (dev@example.test)"})
        self.assertEqual(kwargs["timeout"], 5)
        self.rate_limit.assert_called_once_with()

    def test_name_and_city_fall_back_in_order(self):
        body = {"address": {"neighbourhood": "Indirapuram", "city_district": "Zone 2", "county": "Ghaziabad"}}
        result = self.reverse(http_response(body=body))
        self.assertEqual((result.name, result.city, result.state), ("Indirapuram", "Ghaziabad", ""))

    def test_no_suburb_level_field_returns_none_instead_of_the_city(self):
        body = {"address": {"road": "NH 24", "city": "Noida", "state": "Uttar Pradesh", "country": "India"}}
        self.assertIsNone(self.reverse(http_response(body=body)))

    def test_unable_to_geocode_returns_none(self):
        self.assertIsNone(self.reverse(http_response(body={"error": "Unable to geocode"})))

    def test_429_and_5xx_are_unavailable(self):
        for status in (429, 500, 503):
            with self.subTest(status=status), self.assertRaises(GeocoderUnavailable):
                self.reverse(http_response(status=status))

    def test_network_errors_and_timeouts_are_unavailable(self):
        for error in (requests.ConnectionError("refused"), requests.Timeout("slow")):
            with self.subTest(error=error), self.assertRaises(GeocoderUnavailable):
                self.reverse(side_effect=error)

    def test_empty_user_agent_refuses_to_send(self):
        for value in ("", "   "):
            with self.subTest(value=value), override_settings(NOMINATIM_USER_AGENT=value):
                with self.assertRaises(ImproperlyConfigured):
                    self.reverse(http_response(body=NOIDA_SECTOR_62))
                self.get.assert_not_called()
                self.rate_limit.assert_not_called()


class FakeClock:
    """Stands in for the time module: sleeping only moves the clock."""

    def __init__(self):
        self.now = 1000.0
        self.slept = []

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.slept.append(seconds)
        self.now += seconds


class FakeRedis:
    """SET NX PX and PTTL against the fake clock."""

    def __init__(self, clock):
        self.clock = clock
        self.expires_at = None

    def set(self, key, value, nx=False, px=None):
        if self.expires_at is not None and self.clock.now < self.expires_at:
            return None
        self.expires_at = self.clock.now + px / 1000
        return True

    def pttl(self, key):
        if self.expires_at is None or self.clock.now >= self.expires_at:
            return -2
        return int((self.expires_at - self.clock.now) * 1000)


@override_settings(NOMINATIM_USER_AGENT="ForReal-tests/0.1 (dev@example.test)")
class RateLimiterTests(SimpleTestCase):
    def setUp(self):
        self.clock = FakeClock()
        for target, replacement in (
            ("time", self.clock),
            ("_local_limiter", geocoding._LocalLimiter(geocoding.MIN_INTERVAL_S)),
        ):
            patcher = mock.patch.object(geocoding, target, replacement)
            patcher.start()
            self.addCleanup(patcher.stop)

    def request_times(self, calls=2):
        sent = []

        def get(*args, **kwargs):
            sent.append(self.clock.now)
            return http_response(body=NOIDA_SECTOR_62)

        with mock.patch("requests.get", side_effect=get):
            for _ in range(calls):
                NominatimGeocoder().reverse(28.628, 77.365)
        return sent

    def assert_spaced(self, sent):
        for earlier, later in zip(sent, sent[1:]):
            self.assertGreaterEqual(later - earlier, 1.0)

    def test_redis_limiter_spaces_calls_at_least_a_second_apart(self):
        with mock.patch.object(geocoding, "_redis_client", return_value=FakeRedis(self.clock)):
            sent = self.request_times(3)
        self.assertEqual(sent[0], 1000.0)  # the first call is not delayed
        self.assert_spaced(sent)

    def test_process_local_limiter_takes_over_when_redis_is_down(self):
        with mock.patch.object(geocoding, "_redis_client", side_effect=redis.ConnectionError("down")):
            with self.assertLogs("apps.geo.geocoding", level="WARNING"):
                sent = self.request_times(3)
        self.assertEqual(sent[0], 1000.0)
        self.assert_spaced(sent)

    def test_a_full_queue_is_reported_as_unavailable(self):
        stuck = mock.Mock()
        stuck.set.return_value = None
        stuck.pttl.return_value = 1100
        with mock.patch.object(geocoding, "_redis_client", return_value=stuck):
            with self.assertRaises(GeocoderUnavailable):
                self.request_times(1)


class GoogleGeocoderTests(SimpleTestCase):
    def test_reverse_is_not_implemented(self):
        with self.assertRaises(NotImplementedError):
            GoogleGeocoder().reverse(28.628, 77.365)
