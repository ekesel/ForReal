import uuid

from django.contrib.gis.geos import Point
from django.test import override_settings

from apps.common.testing import API, FAR, HERE, ApiTestCase
from apps.geo.geocoding import GeocodeResult
from apps.geo.models import Locality
from apps.transactions.models import Transaction


class CountingGeocoder:
    provider = "fake"
    enabled = True
    calls = []

    def reverse(self, lat, lng):
        CountingGeocoder.calls.append((lat, lng))
        return GeocodeResult("Sector 62", "Noida", "Uttar Pradesh", self.provider)


class TransactionLocationTests(ApiTestCase):
    def paid_without_location(self, user):
        return self.pay(user, lat=None, lng=None)["transaction"]["id"]

    def post(self, user, txn_id, **body):
        return self.client_for(user).post(f"{API}/transactions/{txn_id}/location/", body or HERE, format="json")

    def test_sets_a_rounded_location_and_returns_the_transaction(self):
        user = self.make_user()
        txn_id = self.paid_without_location(user)
        res = self.post(user, txn_id, lat=28.628049123, lng=77.364912345)
        self.assertEqual(res.status_code, 200, res.data)
        self.assertEqual(res.data["id"], txn_id)
        self.assertEqual(res.data["location"], {"lat": 28.628, "lng": 77.365})
        p = Transaction.objects.get().location
        self.assertEqual((p.y, p.x), (28.628, 77.365))

    def test_second_call_changes_nothing(self):
        user = self.make_user()
        txn_id = self.paid_without_location(user)
        self.post(user, txn_id)
        res = self.post(user, txn_id, **FAR)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["location"], {"lat": 28.628, "lng": 77.365})

    def test_location_sent_at_ingest_is_kept(self):
        user = self.make_user()
        txn_id = self.pay(user)["transaction"]["id"]
        res = self.post(user, txn_id, **FAR)
        self.assertEqual(res.data["location"], {"lat": 28.628, "lng": 77.365})

    def test_needs_the_location_consent(self):
        user = self.make_user(consents=["private_analytics"])
        txn_id = self.paid_without_location(user)
        self.assertEqual(self.post(user, txn_id).status_code, 403)
        self.assertIsNone(Transaction.objects.get().location)

    def test_needs_the_private_analytics_consent(self):
        user = self.make_user(consents=[])
        self.assertEqual(self.post(user, uuid.uuid4()).status_code, 403)

    def test_only_the_owner_can_set_it(self):
        owner, other = self.make_user(), self.make_user()
        txn_id = self.paid_without_location(owner)
        self.assertEqual(self.post(other, txn_id).status_code, 404)
        self.assertEqual(self.post(owner, uuid.uuid4()).status_code, 404)
        self.assertIsNone(Transaction.objects.get().location)

    def test_needs_auth_and_valid_coordinates(self):
        user = self.make_user()
        txn_id = self.paid_without_location(user)
        self.assertEqual(self.client.post(f"{API}/transactions/{txn_id}/location/", HERE, format="json").status_code, 401)
        for body in ({"lat": 28.6}, {"lat": 91, "lng": 77.3}, {"lat": None, "lng": None}):
            res = self.client_for(user).post(f"{API}/transactions/{txn_id}/location/", body, format="json")
            self.assertEqual(res.status_code, 400, body)
        self.assertIsNone(Transaction.objects.get().location)

    def test_known_locality_is_assigned_straight_away(self):
        Locality.objects.create(name="Sector 62", city="Noida", centre=Point(HERE["lng"], HERE["lat"], srid=4326))
        user = self.make_user()
        txn_id = self.paid_without_location(user)
        self.post(user, txn_id)
        self.assertEqual(Transaction.objects.get().locality.name, "Sector 62")

    @override_settings(
        GEOCODER_BACKEND="apps.transactions.tests.test_location.CountingGeocoder", CELERY_TASK_ALWAYS_EAGER=True
    )
    def test_unknown_area_is_geocoded_after_the_commit(self):
        CountingGeocoder.calls = []
        user = self.make_user()
        txn_id = self.paid_without_location(user)
        with self.captureOnCommitCallbacks(execute=True) as callbacks:
            res = self.post(user, txn_id)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(callbacks), 1)
        self.assertEqual(CountingGeocoder.calls, [(28.628, 77.365)])
        self.assertEqual(Transaction.objects.get().locality, Locality.objects.get())
