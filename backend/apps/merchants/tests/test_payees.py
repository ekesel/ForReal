from apps.common.testing import API, FAR, HERE, NEARBY, ApiTestCase
from apps.merchants.models import Merchant, PayeeMerchantLink
from apps.tagging.models import TransactionItem
from apps.transactions.models import Transaction


class ResolvePayeeTests(ApiTestCase):
    def test_pending_lists_unlabelled_payees(self):
        user = self.make_user()
        self.pay(user, "RAMESH KUMAR")
        self.pay(user, "RAMESH KUMAR")
        self.pay(user, "RINA DEVI")
        pending = self.client_for(user).get(f"{API}/payees/pending/").data["payees"]
        self.assertEqual({p["name"]: p["payments"] for p in pending}, {"RAMESH KUMAR": 2, "RINA DEVI": 1})

    def test_marking_a_shop_backfills_all_payments_and_tags_them(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        self.pay(user)
        out = self.resolve_new(user, pid)
        self.assertEqual(out["merchant"]["category"], "tea-stall")
        txns = Transaction.objects.filter(user=user)
        self.assertEqual({t.kind for t in txns}, {"merchant"})
        self.assertEqual(TransactionItem.objects.filter(origin="ai_category", item__name="Tea").count(), 2)
        self.assertEqual(self.client_for(user).get(f"{API}/payees/pending/").data["payees"], [])

    def test_marking_a_person_keeps_payments_private_and_untagged(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        res = self.client_for(user).post(f"{API}/payees/{pid}/resolve/", {"kind": "person"}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(Transaction.objects.get().kind, "person")
        self.assertEqual(Transaction.objects.shareable().count(), 0)
        r = self.pay(user)
        self.assertEqual(r["transaction"]["kind"], "person")
        self.assertIsNone(r["ask"])

    def test_answer_can_be_corrected_from_shop_to_person(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        self.resolve_new(user, pid)
        self.client_for(user).post(f"{API}/payees/{pid}/resolve/", {"kind": "person"}, format="json")
        self.assertEqual(PayeeMerchantLink.objects.get().kind, "person")
        self.assertIsNone(Transaction.objects.get().merchant)
        self.assertFalse(TransactionItem.objects.exists())

    def test_correcting_to_a_different_shop_refreshes_the_guesses(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        self.resolve_new(user, pid)
        self.resolve_new(user, pid, name="Modern Bakery", category="bakery")
        self.assertEqual([ti.item.name for ti in TransactionItem.objects.all()], ["Cake"])

    def test_resolve_payload_is_validated(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        c = self.client_for(user)
        for body in (
            {"kind": "merchant"},
            {"kind": "person", "new_merchant": {"name": "X", "category": "food"}},
            {"kind": "merchant", "new_merchant": {"name": "X", "category": "no-such"}},
        ):
            self.assertEqual(c.post(f"{API}/payees/{pid}/resolve/", body, format="json").status_code, 400, body)

    def test_cannot_resolve_a_payee_you_never_paid(self):
        pid = self.pay(self.make_user())["transaction"]["payee"]["id"]
        res = self.client_for(self.make_user()).post(f"{API}/payees/{pid}/resolve/", {"kind": "person"}, format="json")
        self.assertEqual(res.status_code, 404)

    def test_same_shop_entered_twice_nearby_is_one_merchant(self):
        a, b = self.make_user(), self.make_user()
        pid = self.pay(a)["transaction"]["payee"]["id"]
        self.pay(b, **NEARBY)
        self.resolve_new(a, pid, name="Sharma Tea Stall")
        self.resolve_new(b, pid, name="sharma tea stal", **NEARBY)
        self.assertEqual(Merchant.objects.count(), 1)

    def test_same_name_far_away_is_a_different_merchant(self):
        a, b = self.make_user(), self.make_user()
        pid = self.pay(a)["transaction"]["payee"]["id"]
        self.pay(b, **FAR)
        self.resolve_new(a, pid)
        self.resolve_new(b, pid, **FAR)
        self.assertEqual(Merchant.objects.count(), 2)

    def test_merchant_search_is_fuzzy_and_local(self):
        user = self.make_user()
        pid = self.pay(user)["transaction"]["payee"]["id"]
        self.resolve_new(user, pid)
        c = self.client_for(user)
        hit = c.get(f"{API}/merchants/search/", {"q": "sharma", **HERE}).data["merchants"]
        self.assertEqual([m["name"] for m in hit], ["Sharma Tea Stall"])
        self.assertEqual(c.get(f"{API}/merchants/search/", {"q": "sharma", **FAR}).data["merchants"], [])


class CrowdMatchingTests(ApiTestCase):
    def confirm(self, n, **loc):
        """n different users pay RAMESH KUMAR and label him as Sharma Tea Stall."""
        users = [self.make_user() for _ in range(n)]
        for u in users:
            pid = self.pay(u, **(loc or HERE))["transaction"]["payee"]["id"]
            self.resolve_new(u, pid, **(loc or HERE))
        return users, pid

    def test_no_suggestion_below_the_confirmation_threshold(self):
        self.confirm(1)
        r = self.pay(self.make_user(), **NEARBY)
        self.assertEqual(r["ask"], "payee")
        self.assertEqual(r["payee_suggestions"], [])

    def test_suggested_once_enough_users_agree(self):
        self.confirm(2)
        newcomer = self.make_user()
        r = self.pay(newcomer, **NEARBY)
        self.assertEqual([m["name"] for m in r["payee_suggestions"]], ["Sharma Tea Stall"])
        pid = r["transaction"]["payee"]["id"]
        res = self.client_for(newcomer).get(f"{API}/payees/{pid}/suggestions/", NEARBY)
        self.assertEqual(len(res.data["crowd"]), 1)
        # Accepting the suggestion by id resolves the payee.
        body = {"kind": "merchant", "merchant_id": res.data["crowd"][0]["id"], **NEARBY}
        self.assertEqual(self.client_for(newcomer).post(f"{API}/payees/{pid}/resolve/", body, format="json").status_code, 200)
        self.assertEqual(Transaction.objects.get(user=newcomer).merchant.name, "Sharma Tea Stall")

    def test_same_name_in_another_area_is_not_suggested(self):
        self.confirm(2)
        r = self.pay(self.make_user(), **FAR)
        self.assertEqual(r["payee_suggestions"], [])

    def test_users_without_community_consent_do_not_count(self):
        users, _ = self.confirm(2)
        self.client_for(users[0]).post(
            f"{API}/consents/", {"purpose": "community_rankings", "granted": False, "notice_version": "v1"}, format="json"
        )
        r = self.pay(self.make_user(), **NEARBY)
        self.assertEqual(r["payee_suggestions"], [])

    def test_person_labels_are_never_suggested(self):
        for _ in range(3):
            u = self.make_user()
            pid = self.pay(u)["transaction"]["payee"]["id"]
            self.client_for(u).post(f"{API}/payees/{pid}/resolve/", {"kind": "person"}, format="json")
        r = self.pay(self.make_user())
        self.assertEqual(r["payee_suggestions"], [])

    def test_online_merchants_match_regardless_of_distance(self):
        for _ in range(2):
            u = self.make_user()
            pid = self.pay(u, "RAPIDO")["transaction"]["payee"]["id"]
            body = {"kind": "merchant", "new_merchant": {"name": "Rapido", "category": "transport", "is_online": True}}
            self.client_for(u).post(f"{API}/payees/{pid}/resolve/", body, format="json")
        self.assertEqual(Merchant.objects.count(), 1)
        r = self.pay(self.make_user(), "RAPIDO", **FAR)
        self.assertEqual([m["name"] for m in r["payee_suggestions"]], ["Rapido"])
