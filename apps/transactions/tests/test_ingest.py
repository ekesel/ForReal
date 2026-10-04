import uuid
from datetime import date, timedelta

from django.contrib.gis.geos import Point

from apps.common.testing import API, HERE, ApiTestCase
from apps.geo.models import Locality
from apps.transactions.models import Transaction
from apps.transactions.services import hash_ref


class IngestTests(ApiTestCase):
    def test_new_payment_is_stored_as_unknown_and_asks_about_the_payee(self):
        user = self.make_user()
        r = self.pay(user, "RAMESH  KUMAR", ref="400012345678")
        self.assertEqual(r["status"], "created")
        self.assertEqual(r["ask"], "payee")
        txn = r["transaction"]
        self.assertEqual(txn["kind"], "unknown")
        self.assertEqual(txn["payee"]["name"], "RAMESH  KUMAR")
        self.assertEqual(txn["sources"], ["sms"])
        self.assertIsNone(txn["merchant"])
        self.assertEqual(txn["items"], [])

    def test_payee_names_are_normalised_to_one_payee(self):
        user = self.make_user()
        a = self.pay(user, "RAMESH  KUMAR")
        b = self.pay(user, "ramesh kumar ")
        self.assertEqual(a["transaction"]["payee"]["id"], b["transaction"]["payee"]["id"])

    def test_reference_is_stored_only_as_a_hash(self):
        user = self.make_user()
        self.pay(user, ref="400012345678")
        txn = Transaction.objects.get()
        self.assertEqual(txn.ref_hash, hash_ref("400012345678"))
        self.assertNotIn("400012345678", txn.ref_hash)
        self.assertEqual(len(txn.ref_hash), 64)

    def test_retrying_the_same_upload_does_not_duplicate(self):
        user = self.make_user()
        c = self.client_for(user)
        row = self.row(ref="1")
        self.ingest(c, row)
        again = self.ingest(c, row)[0]
        self.assertEqual(again["status"], "duplicate")
        self.assertEqual(Transaction.objects.count(), 1)

    def test_same_reference_from_another_lane_merges(self):
        user = self.make_user()
        first = self.pay(user, ref="400012345678", source="sms")
        second = self.pay(user, ref="400012345678", source="email")
        self.assertEqual(second["status"], "merged")
        self.assertEqual(second["transaction"]["id"], first["transaction"]["id"])
        self.assertEqual(Transaction.objects.get().sources, ["sms", "email"])

    def test_same_reference_for_two_users_is_two_payments(self):
        self.pay(self.make_user(), ref="77")
        self.pay(self.make_user(), ref="77")
        self.assertEqual(Transaction.objects.count(), 2)

    def test_payments_without_a_reference_do_not_merge(self):
        user = self.make_user()
        self.pay(user)
        self.pay(user)
        self.assertEqual(Transaction.objects.count(), 2)

    def test_fields_that_must_stay_on_the_device_are_refused(self):
        c = self.client_for(self.make_user())
        for leaked in ({"amount": 300}, {"raw_text": "Sent Rs.300.00 ..."}, {"account_last4": "1234"}):
            res = c.post(f"{API}/transactions/batch/", {"transactions": [self.row(**leaked)]}, format="json")
            self.assertEqual(res.status_code, 400, leaked)
        self.assertFalse(Transaction.objects.exists())

    def test_validation(self):
        c = self.client_for(self.make_user())
        bad = [
            self.row(amount_band="300"),
            self.row(source="carrier-pigeon"),
            self.row(occurred_on=(date.today() + timedelta(days=5)).isoformat()),
            {k: v for k, v in self.row().items() if k != "lng"},
        ]
        for row in bad:
            res = c.post(f"{API}/transactions/batch/", {"transactions": [row]}, format="json")
            self.assertEqual(res.status_code, 400, row)
        res = c.post(f"{API}/transactions/batch/", {"transactions": [self.row() for _ in range(201)]}, format="json")
        self.assertEqual(res.status_code, 400)

    def test_location_is_rounded_before_storage(self):
        user = self.make_user()
        self.pay(user, lat=28.628049123, lng=77.364912345)
        p = Transaction.objects.get().location
        self.assertEqual((p.y, p.x), (28.628, 77.365))

    def test_location_is_dropped_without_location_consent(self):
        user = self.make_user(consents=["private_analytics"])
        r = self.pay(user)
        self.assertIsNone(r["transaction"]["location"])
        self.assertIsNone(Transaction.objects.get().location)

    def test_locality_is_assigned_from_location(self):
        Locality.objects.create(name="Sector 62", city="Noida", centre=Point(HERE["lng"], HERE["lat"], srid=4326))
        Locality.objects.create(name="Sector 18", city="Noida", centre=Point(77.3260, 28.5708, srid=4326))
        self.pay(self.make_user())
        self.assertEqual(Transaction.objects.get().locality.name, "Sector 62")

    def test_users_only_see_their_own_transactions(self):
        mine, theirs = self.make_user(), self.make_user()
        self.pay(mine)
        other = self.pay(theirs)
        c = self.client_for(mine)
        listing = c.get(f"{API}/transactions/").data
        self.assertEqual(len(listing["results"]), 1)
        self.assertEqual(c.get(f"{API}/transactions/{other['transaction']['id']}/").status_code, 404)
        self.assertEqual(c.get(f"{API}/transactions/{uuid.uuid4()}/").status_code, 404)

    def test_a_known_payee_is_resolved_at_ingest(self):
        user = self.make_user()
        first = self.pay(user)
        self.resolve_new(user, first["transaction"]["payee"]["id"])
        r = self.pay(user)
        self.assertEqual(r["transaction"]["kind"], "merchant")
        self.assertEqual(r["transaction"]["merchant"]["name"], "Sharma Tea Stall")
        self.assertEqual(r["ask"], "items")
