from django.core.exceptions import ValidationError

from apps.common.testing import API, ApiTestCase
from apps.parsers.models import ParserTemplate, compile_pattern

HDFC_SMS = (
    "Sent Rs.300.00\nFrom HDFC Bank A/C *1234\nTo RAMESH  KUMAR\nOn 02/08/26\nRef 400012345678\n"
    "Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808"
)


class ParserTemplateTests(ApiTestCase):
    def test_seeded_hdfc_template_parses_the_real_message_shape(self):
        t = ParserTemplate.objects.get(bank="HDFC")
        t.full_clean()
        m = compile_pattern(t.pattern, t.flags).search(HDFC_SMS)
        self.assertEqual(m["amount"], "300.00")
        self.assertEqual(" ".join(m["payee"].split()), "RAMESH KUMAR")
        self.assertEqual(m["date"], "02/08/26")
        self.assertEqual(m["ref"], "400012345678")

    def test_template_does_not_match_otp_or_credit_messages(self):
        rx = compile_pattern(ParserTemplate.objects.get(bank="HDFC").pattern, "s")
        self.assertIsNone(rx.search("123456 is your OTP for txn of Rs.300.00 at HDFC Bank. Do not share."))
        self.assertIsNone(rx.search("Rs.500.00 credited to HDFC Bank A/C *1234 from VPA x@okaxis"))

    def test_bad_templates_are_rejected(self):
        base = dict(bank="X", sender_ids=["XBANK"])
        cases = {
            "pattern": dict(name="a", pattern=r"Sent (?<amount>\d+"),
            "pattern ": dict(name="b", pattern=r"Sent (?<amount>\d+)"),  # no payee group
            "sample": dict(name="c", pattern=r"Paid (?<amount>\d+) to (?<payee>\w+)", sample="Sent 5 to Bob"),
        }
        for field, extra in cases.items():
            with self.assertRaises(ValidationError) as ctx:
                ParserTemplate(**base, **extra).full_clean()
            self.assertIn(field.strip(), ctx.exception.message_dict)

    def test_app_downloads_templates_and_skips_when_unchanged(self):
        c = self.client_for(self.make_user(consents=[]))
        first = c.get(f"{API}/parser-templates/").data
        self.assertTrue(first["changed"])
        self.assertEqual(first["templates"][0]["sender_ids"], ["HDFCBK"])
        self.assertIn("(?<amount>", first["templates"][0]["pattern"])
        again = c.get(f"{API}/parser-templates/", {"version": first["version"]}).data
        self.assertEqual(again, {"version": first["version"], "changed": False})

    def test_inactive_templates_are_not_served(self):
        ParserTemplate.objects.update(is_active=False)
        c = self.client_for(self.make_user(consents=[]))
        self.assertEqual(c.get(f"{API}/parser-templates/").data["templates"], [])
