from apps.common.testing import API, ApiTestCase
from apps.tagging.models import Item, TagWeight, TransactionItem


class TaggingTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.user = self.make_user()
        self.c = self.client_for(self.user)
        first = self.pay(self.user)
        self.payee_id = first["transaction"]["payee"]["id"]
        self.resolve_new(self.user, self.payee_id)
        self.txn_id = first["transaction"]["id"]

    def items(self, txn_id=None):
        txn = self.c.get(f"{API}/transactions/{txn_id or self.txn_id}/").data
        return {(i["item"]["name"], i["quantity"], i["origin"]) for i in txn["items"]}

    def set_items(self, txn_id, *entries):
        res = self.c.put(f"{API}/transactions/{txn_id}/items/", {"items": list(entries)}, format="json")
        self.assertEqual(res.status_code, 200, res.data)
        return res.data["items"]

    def test_unanswered_payment_keeps_a_lower_confidence_ai_tag(self):
        self.assertEqual(self.items(), {("Tea", 1, "ai_category")})
        ti = TransactionItem.objects.get()
        self.assertLess(ti.confidence, 1.0)
        self.assertTrue(self.c.get(f"{API}/transactions/{self.txn_id}/").data["items"][0]["inferred"])

    def test_one_tap_yes_confirms_the_guess(self):
        res = self.c.post(f"{API}/transactions/{self.txn_id}/items/confirm/")
        self.assertEqual(res.status_code, 200)
        ti = TransactionItem.objects.get()
        self.assertEqual((ti.origin, ti.confidence, ti.ai_origin), ("user", 1.0, "ai_category"))

    def test_several_items_with_quantities(self):
        tea = Item.objects.get(slug="tea")
        self.set_items(self.txn_id, {"item_id": tea.id, "quantity": 2}, {"name": "Bread"})
        self.assertEqual(self.items(), {("Tea", 2, "user"), ("Bread", 1, "user")})

    def test_replacing_a_guess_keeps_it_as_rejected_for_weight_tuning(self):
        self.set_items(self.txn_id, {"name": "samosa"})
        self.assertEqual(self.items(), {("Samosa", 1, "user")})
        rejected = TransactionItem.objects.get(item__slug="tea")
        self.assertIsNotNone(rejected.rejected_at)
        self.assertEqual(rejected.origin, "ai_category")

    def test_free_text_resolves_through_aliases_and_spelling(self):
        self.set_items(self.txn_id, {"name": "Chai"}, {"name": "samosas"}, {"name": "  CAKE "})
        self.assertEqual({name for name, _, _ in self.items()}, {"Tea", "Samosa", "Cake"})

    def test_unknown_item_is_added_to_the_catalogue_unverified(self):
        self.set_items(self.txn_id, {"name": "bun maska"})
        item = Item.objects.get(name="Bun Maska")
        self.assertFalse(item.is_verified)
        self.assertEqual(item.created_by, self.user)
        self.set_items(self.txn_id, {"name": "Bun  Maska"})
        self.assertEqual(Item.objects.filter(name="Bun Maska").count(), 1)

    def test_entries_are_validated(self):
        for entry in ({}, {"item_id": 1, "name": "Tea"}, {"name": "Tea", "quantity": 0}):
            res = self.c.put(f"{API}/transactions/{self.txn_id}/items/", {"items": [entry]}, format="json")
            self.assertEqual(res.status_code, 400, entry)
        self.assertEqual(self.c.put(f"{API}/transactions/{self.txn_id}/items/", {"items": []}, format="json").status_code, 400)

    def test_own_history_beats_the_category_default(self):
        self.set_items(self.txn_id, {"name": "coffee", "quantity": 2})
        r = self.pay(self.user)
        self.assertEqual(self.items(r["transaction"]["id"]), {("Coffee", 2, "ai_own_history")})

    def test_own_history_prefers_the_same_amount_band(self):
        self.set_items(self.txn_id, {"name": "tea"})
        big = self.pay(self.user, amount_band="50_200")
        self.set_items(big["transaction"]["id"], {"name": "tea", "quantity": 2}, {"name": "bread"})
        small = self.pay(self.user, amount_band="lt_50")
        self.assertEqual(self.items(small["transaction"]["id"]), {("Tea", 1, "ai_own_history")})
        large = self.pay(self.user, amount_band="50_200")
        self.assertEqual(self.items(large["transaction"]["id"]), {("Tea", 2, "ai_own_history"), ("Bread", 1, "ai_own_history")})

    def test_prompts_stop_once_the_item_is_learned(self):
        self.c.post(f"{API}/transactions/{self.txn_id}/items/confirm/")
        for expected_ask in ("items", "items", None):
            r = self.pay(self.user)
            self.assertEqual(r["ask"], expected_ask)
            self.c.post(f"{API}/transactions/{r['transaction']['id']}/items/confirm/")

    def test_crowd_tags_need_enough_confirming_users(self):
        def other_user_tags(name):
            u = self.make_user()
            r = self.pay(u)
            self.resolve_new(u, r["transaction"]["payee"]["id"])
            last = self.pay(u)
            self.client_for(u).put(f"{API}/transactions/{last['transaction']['id']}/items/", {"items": [{"name": name}]}, format="json")

        other_user_tags("samosa")
        newcomer = self.make_user()
        r = self.pay(newcomer)
        self.resolve_new(newcomer, r["transaction"]["payee"]["id"])
        nc = self.client_for(newcomer)
        sug = nc.get(f"{API}/transactions/{r['transaction']['id']}/suggestions/").data["suggestions"]
        self.assertEqual(sug[0]["origin"], "ai_category")  # one user is below the threshold
        other_user_tags("samosa")
        sug = nc.get(f"{API}/transactions/{r['transaction']['id']}/suggestions/").data["suggestions"]
        self.assertEqual((sug[0]["item"]["name"], sug[0]["origin"]), ("Samosa", "ai_crowd"))

    def test_ai_guesses_never_feed_crowd_suggestions(self):
        # Three users with only AI-guessed "Tea" tags must not produce a crowd suggestion.
        for _ in range(3):
            u = self.make_user()
            r = self.pay(u)
            self.resolve_new(u, r["transaction"]["payee"]["id"])
        sug = self.c.get(f"{API}/transactions/{self.txn_id}/suggestions/").data["suggestions"]
        self.assertEqual(sug[0]["origin"], "ai_category")

    def test_person_payments_cannot_be_tagged(self):
        self.c.post(f"{API}/payees/{self.payee_id}/resolve/", {"kind": "person"}, format="json")
        res = self.c.put(f"{API}/transactions/{self.txn_id}/items/", {"items": [{"name": "tea"}]}, format="json")
        self.assertEqual(res.status_code, 400)

    def test_cannot_tag_someone_elses_payment(self):
        res = self.client_for(self.make_user()).put(
            f"{API}/transactions/{self.txn_id}/items/", {"items": [{"name": "tea"}]}, format="json"
        )
        self.assertEqual(res.status_code, 404)

    def test_item_search_for_chips(self):
        names = [i["name"] for i in self.c.get(f"{API}/items/", {"category": "bakery"}).data["items"]]
        self.assertIn("Cake", names)
        self.assertNotIn("Petrol", names)
        names = [i["name"] for i in self.c.get(f"{API}/items/", {"q": "cha"}).data["items"]]
        self.assertEqual(names, ["Tea"])

    def test_weights_are_seeded_for_every_origin(self):
        self.assertEqual(
            dict(TagWeight.objects.values_list("origin", "weight")),
            {"user": 1.0, "ai_own_history": 0.8, "ai_crowd": 0.6, "ai_category": 0.3, "ai_llm": 0.2},
        )
