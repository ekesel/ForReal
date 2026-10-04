from apps.common.testing import API, HERE, ApiTestCase
from apps.merchants.models import PayeeMerchantLink
from apps.transactions.models import Transaction


class ConsentTests(ApiTestCase):
    def post(self, client, purpose, granted):
        return client.post(f"{API}/consents/", {"purpose": purpose, "granted": granted, "notice_version": "v1"}, format="json")

    def test_everything_is_off_by_default(self):
        res = self.client_for(self.make_user(consents=[])).get(f"{API}/consents/")
        self.assertEqual(set(res.data["consents"].values()), {False})
        self.assertEqual(len(res.data["consents"]), 5)

    def test_dependent_consent_needs_its_parent(self):
        c = self.client_for(self.make_user(consents=[]))
        self.assertEqual(self.post(c, "community_rankings", True).status_code, 400)
        self.post(c, "private_analytics", True)
        self.assertEqual(self.post(c, "show_name", True).status_code, 400)
        self.assertEqual(self.post(c, "community_rankings", True).status_code, 200)
        self.assertTrue(self.post(c, "show_name", True).data["consents"]["show_name"])

    def test_history_keeps_every_change(self):
        c = self.client_for(self.make_user(consents=[]))
        self.post(c, "private_analytics", True)
        self.post(c, "private_analytics", True)  # no-op, not recorded twice
        self.post(c, "private_analytics", False)
        history = c.get(f"{API}/consents/history/").data["history"]
        self.assertEqual([h["granted"] for h in history], [True, False])

    def test_withdrawing_community_cascades_to_dependents(self):
        user = self.make_user(consents=["private_analytics", "community_rankings", "show_name", "merchant_insights"])
        state = self.post(self.client_for(user), "community_rankings", False).data["consents"]
        self.assertFalse(state["show_name"])
        self.assertFalse(state["merchant_insights"])
        self.assertTrue(state["private_analytics"])

    def test_withdrawing_community_removes_user_from_shareable_data(self):
        user = self.make_user()
        r = self.pay(user)
        self.resolve_new(user, r["transaction"]["payee"]["id"])
        self.assertEqual(Transaction.objects.shareable().count(), 1)
        self.post(self.client_for(user), "community_rankings", False)
        self.assertEqual(Transaction.objects.shareable().count(), 0)
        self.assertEqual(Transaction.objects.filter(user=user).count(), 1)  # private view keeps it

    def test_withdrawing_location_erases_stored_locations(self):
        user = self.make_user()
        r = self.pay(user)
        self.resolve_new(user, r["transaction"]["payee"]["id"])
        self.post(self.client_for(user), "location", False)
        self.assertIsNone(Transaction.objects.get(user=user).location)
        self.assertIsNone(PayeeMerchantLink.objects.get(user=user).location)

    def test_withdrawing_private_analytics_deletes_payment_data_and_blocks_ingest(self):
        user = self.make_user()
        c = self.client_for(user)
        r = self.pay(user)
        self.resolve_new(user, r["transaction"]["payee"]["id"])
        self.post(c, "private_analytics", False)
        self.assertFalse(Transaction.objects.filter(user=user).exists())
        self.assertFalse(PayeeMerchantLink.objects.filter(user=user).exists())
        res = c.post(f"{API}/transactions/batch/", {"transactions": [self.row()]}, format="json")
        self.assertEqual(res.status_code, 403)
        self.assertEqual(c.get(f"{API}/transactions/").status_code, 403)
