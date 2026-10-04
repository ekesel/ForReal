from django.test import override_settings

from apps.accounts.models import OtpChallenge, User
from apps.common.testing import API, ApiTestCase


@override_settings(OTP_ECHO_IN_RESPONSE=True)
class OtpFlowTests(ApiTestCase):
    def request_code(self, phone="9876543210"):
        res = self.client.post(f"{API}/auth/otp/request/", {"phone": phone}, format="json")
        self.assertEqual(res.status_code, 200, res.data)
        return res.data["debug_code"]

    def test_new_user_signs_in_and_gets_tokens(self):
        code = self.request_code()
        res = self.client.post(f"{API}/auth/otp/verify/", {"phone": "9876543210", "code": code}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data["is_new_user"])
        self.assertEqual(res.data["user"]["phone"], "+919876543210")
        me = self.client.get(f"{API}/me/", HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        self.assertEqual(me.status_code, 200)
        refreshed = self.client.post(f"{API}/auth/token/refresh/", {"refresh": res.data["refresh"]}, format="json")
        self.assertIn("access", refreshed.data)

    def test_returning_user_is_not_new(self):
        User.objects.create_user("+919876543210")
        code = self.request_code()
        res = self.client.post(f"{API}/auth/otp/verify/", {"phone": "+919876543210", "code": code}, format="json")
        self.assertFalse(res.data["is_new_user"])
        self.assertEqual(User.objects.count(), 1)

    def test_code_is_stored_hashed_and_single_use(self):
        code = self.request_code()
        self.assertNotIn(code, OtpChallenge.objects.get().code_hash)
        body = {"phone": "9876543210", "code": code}
        self.assertEqual(self.client.post(f"{API}/auth/otp/verify/", body, format="json").status_code, 200)
        self.assertEqual(self.client.post(f"{API}/auth/otp/verify/", body, format="json").status_code, 400)

    def test_wrong_code_is_rejected_and_attempts_are_capped(self):
        code = self.request_code()
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(5):
            res = self.client.post(f"{API}/auth/otp/verify/", {"phone": "9876543210", "code": wrong}, format="json")
            self.assertEqual(res.data["code"], "invalid")
        res = self.client.post(f"{API}/auth/otp/verify/", {"phone": "9876543210", "code": code}, format="json")
        self.assertEqual(res.data["code"], "too_many_attempts")
        self.assertFalse(User.objects.exists())

    def test_requests_per_phone_are_rate_limited(self):
        for _ in range(5):
            self.request_code()
        res = self.client.post(f"{API}/auth/otp/request/", {"phone": "9876543210"}, format="json")
        self.assertEqual(res.status_code, 429)

    def test_only_the_newest_code_works(self):
        old = self.request_code()
        new = self.request_code()
        if old != new:
            res = self.client.post(f"{API}/auth/otp/verify/", {"phone": "9876543210", "code": old}, format="json")
            self.assertEqual(res.status_code, 400)

    def test_invalid_phone_is_rejected(self):
        res = self.client.post(f"{API}/auth/otp/request/", {"phone": "12"}, format="json")
        self.assertEqual(res.status_code, 400)

    @override_settings(OTP_ECHO_IN_RESPONSE=False)
    def test_code_is_not_echoed_in_production(self):
        res = self.client.post(f"{API}/auth/otp/request/", {"phone": "9876543210"}, format="json")
        self.assertNotIn("debug_code", res.data)

    def test_endpoints_need_authentication(self):
        for path in ["me/", "consents/", "transactions/", "payees/pending/", "parser-templates/"]:
            self.assertEqual(self.client.get(f"{API}/{path}").status_code, 401, path)
