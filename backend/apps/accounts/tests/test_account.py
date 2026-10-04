from apps.accounts.models import Device, User
from apps.common.testing import API, ApiTestCase
from apps.consents.models import Consent
from apps.merchants.models import Merchant, PayeeMerchantLink
from apps.tagging.models import TransactionItem
from apps.transactions.models import Transaction


class AccountTests(ApiTestCase):
    def test_device_registration_is_an_upsert(self):
        user = self.make_user()
        c = self.client_for(user)
        body = {"device_id": "abc", "platform": "android", "app_version": "0.1.0", "push_token": "t1"}
        self.assertEqual(c.put(f"{API}/me/device/", body, format="json").status_code, 200)
        c.put(f"{API}/me/device/", {**body, "push_token": "t2"}, format="json")
        self.assertEqual(Device.objects.get(user=user).push_token, "t2")

    def test_profile_update_cannot_change_phone(self):
        user = self.make_user()
        res = self.client_for(user).patch(f"{API}/me/", {"display_name": "Eku", "phone": "+911111111111"}, format="json")
        self.assertEqual(res.data["display_name"], "Eku")
        self.assertEqual(res.data["phone"], user.phone)

    def test_export_contains_everything_held(self):
        user = self.make_user()
        r = self.pay(user)
        self.resolve_new(user, r["transaction"]["payee"]["id"])
        data = self.client_for(user).get(f"{API}/me/export/").data
        self.assertEqual(data["user"]["phone"], user.phone)
        self.assertEqual(len(data["consent_history"]), 3)
        self.assertEqual(data["payees"][0]["merchant"], "Sharma Tea Stall")
        txn = data["transactions"][0]
        self.assertEqual(txn["amount_band"], "lt_50")
        self.assertEqual(txn["items"][0]["item"], "Tea")

    def test_delete_removes_personal_data_but_keeps_the_shop(self):
        user, other = self.make_user(), self.make_user()
        r = self.pay(user)
        self.resolve_new(user, r["transaction"]["payee"]["id"])
        self.pay(other)
        res = self.client_for(user).delete(f"{API}/me/")
        self.assertEqual(res.status_code, 204)
        self.assertFalse(User.objects.filter(pk=user.pk).exists())
        self.assertFalse(Transaction.objects.filter(user_id=user.pk).exists())
        self.assertFalse(Consent.objects.filter(user_id=user.pk).exists())
        self.assertFalse(PayeeMerchantLink.objects.exists())
        self.assertEqual(TransactionItem.objects.count(), 0)
        self.assertIsNone(Merchant.objects.get().created_by)
        self.assertEqual(Transaction.objects.filter(user=other).count(), 1)
