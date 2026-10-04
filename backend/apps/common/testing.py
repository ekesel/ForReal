import uuid
from datetime import date

from django.core.cache import cache
from rest_framework.test import APIClient, APITestCase

from apps.accounts.models import User
from apps.consents.services import set_consent

API = "/api/v1"
ALL = ["private_analytics", "community_rankings", "location"]
# Two points about 110 m apart in Sector 62, Noida, and one about 11 km away.
HERE = {"lat": 28.6280, "lng": 77.3649}
NEARBY = {"lat": 28.6290, "lng": 77.3649}
FAR = {"lat": 28.5355, "lng": 77.3910}


class ApiTestCase(APITestCase):
    _n = 0

    def setUp(self):
        cache.clear()  # throttle counters

    def make_user(self, consents=ALL):
        ApiTestCase._n += 1
        user = User.objects.create_user(f"+9198{ApiTestCase._n:08d}")
        for purpose in consents:
            set_consent(user, purpose, True, "v1")
        return user

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def row(self, payee="RAMESH KUMAR", **over):
        data = {
            "client_txn_id": str(uuid.uuid4()),
            "payee_name": payee,
            "occurred_on": date.today().isoformat(),
            "day_part": "evening",
            "amount_band": "lt_50",
            "source": "sms",
            **HERE,
        }
        data.update(over)
        return data

    def ingest(self, client, *rows):
        res = client.post(f"{API}/transactions/batch/", {"transactions": list(rows)}, format="json")
        self.assertEqual(res.status_code, 200, res.data)
        return res.data["results"]

    def pay(self, user, payee="RAMESH KUMAR", **over):
        """Ingest one payment and return its result row."""
        return self.ingest(self.client_for(user), self.row(payee, **over))[0]

    def resolve_new(self, user, payee_id, name="Sharma Tea Stall", category="tea-stall", **loc):
        body = {"kind": "merchant", "new_merchant": {"name": name, "category": category}, **(loc or HERE)}
        res = self.client_for(user).post(f"{API}/payees/{payee_id}/resolve/", body, format="json")
        self.assertEqual(res.status_code, 200, res.data)
        return res.data
