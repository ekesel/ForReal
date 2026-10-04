import os
import subprocess
import sys

from django.conf import settings
from django.test import SimpleTestCase, override_settings

from apps.accounts.apps import AccountsConfig
from apps.accounts.models import OtpChallenge, User, normalize_phone
from apps.accounts.otp import ConsoleOtpSender
from apps.common.testing import API, ApiTestCase
from config.startup import (
    CONSOLE_SENDER,
    StartupError,
    check_sender_class,
    check_sign_in,
    closed_testing_warning,
    parse_tester_phones,
)

LISTED = "+919876543210"
UNLISTED = "+919812345678"
RECORDER = "apps.accounts.tests.test_closed_testing.RecordingSender"
REAL_SENDER = "sms.provider.Sender"


class RecordingSender:
    """Stands in for a real SMS provider and records what it was asked to send."""

    sent = []

    def send(self, phone, code):
        RecordingSender.sent.append((phone, code))


class QuietSender(ConsoleOtpSender):
    """A console sender by another name: must not get past the production check."""


@override_settings(TESTER_PHONES=(LISTED,), OTP_SENDER=RECORDER, OTP_ECHO_IN_RESPONSE=False)
class ClosedTestingSignInTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        RecordingSender.sent = []

    def request(self, phone):
        return self.client.post(f"{API}/auth/otp/request/", {"phone": phone}, format="json")

    def verify(self, phone, code):
        return self.client.post(f"{API}/auth/otp/verify/", {"phone": phone, "code": code}, format="json")

    def test_listed_phone_gets_the_code_in_the_response_and_no_sms(self):
        res = self.request(LISTED)
        self.assertEqual(res.status_code, 200, res.data)
        self.assertRegex(res.data["debug_code"], r"^\d{6}$")
        self.assertEqual(RecordingSender.sent, [], "no SMS in closed testing, whatever OTP_SENDER is")

        signed_in = self.verify(LISTED, res.data["debug_code"])
        self.assertEqual(signed_in.status_code, 200, signed_in.data)
        self.assertIn("access", signed_in.data)
        self.assertEqual(signed_in.data["user"]["phone"], LISTED)

    def test_listed_phone_in_local_format_is_recognised(self):
        res = self.request("98765 43210")
        self.assertEqual(res.status_code, 200, res.data)
        self.assertIn("debug_code", res.data)

    def test_unlisted_phone_is_refused_and_nothing_is_created_or_sent(self):
        res = self.request(UNLISTED)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.json(), {"code": "not_invited", "detail": "This number is not on the test list."})
        self.assertFalse(OtpChallenge.objects.exists())
        self.assertEqual(RecordingSender.sent, [])

    def test_unlisted_phone_cannot_verify_even_with_a_live_challenge(self):
        # A code requested before closed testing was switched on.
        with override_settings(TESTER_PHONES=(), OTP_ECHO_IN_RESPONSE=True):
            code = self.request(UNLISTED).data["debug_code"]
        res = self.verify(UNLISTED, code)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.json()["code"], "not_invited")
        self.assertFalse(User.objects.filter(phone=UNLISTED).exists())
        self.assertEqual(OtpChallenge.objects.get().attempts, 0, "a refused number does not burn attempts")

    def test_digits_of_other_scripts_do_not_pass_for_a_listed_number(self):
        devanagari = "+91" + "".join(chr(0x0966 + int(d)) for d in LISTED[3:])
        self.assertNotIn(normalize_phone(devanagari), settings.TESTER_PHONES)
        res = self.request(devanagari)
        self.assertEqual(res.status_code, 400, "not a phone number at all")
        self.assertFalse(OtpChallenge.objects.exists())

    def test_an_existing_user_who_is_not_listed_cannot_sign_in(self):
        User.objects.create_user(UNLISTED)
        self.assertEqual(self.request(UNLISTED).status_code, 403)

    def test_per_phone_rate_limit_still_applies(self):
        for _ in range(settings.OTP_MAX_REQUESTS_PER_HOUR):
            self.assertEqual(self.request(LISTED).status_code, 200)
        res = self.request(LISTED)
        self.assertEqual(res.status_code, 429)
        self.assertEqual(res.json()["code"], "too_many_requests")
        self.assertNotIn("debug_code", res.json())

    def test_attempt_cap_still_applies(self):
        code = self.request(LISTED).data["debug_code"]
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(settings.OTP_MAX_ATTEMPTS):
            self.assertEqual(self.verify(LISTED, wrong).json()["code"], "invalid")
        res = self.verify(LISTED, code)
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.json()["code"], "too_many_attempts")

    def test_removing_tester_phones_restores_normal_sign_in(self):
        with override_settings(TESTER_PHONES=()):
            res = self.request(UNLISTED)
            self.assertEqual(res.status_code, 200, res.data)
            self.assertNotIn("debug_code", res.data, "the code is no longer returned")
            self.assertEqual(len(RecordingSender.sent), 1, "the code goes out through OTP_SENDER again")
            phone, code = RecordingSender.sent[0]
            self.assertEqual(phone, UNLISTED)
            self.assertEqual(self.verify(UNLISTED, code).status_code, 200)

    def test_normal_mode_with_echo_still_returns_the_code_and_sends(self):
        with override_settings(TESTER_PHONES=(), OTP_ECHO_IN_RESPONSE=True):
            res = self.request(UNLISTED)
            self.assertIn("debug_code", res.data)
            self.assertEqual(len(RecordingSender.sent), 1)


class StartupCheckTests(SimpleTestCase):
    def check(self, **over):
        args = dict(debug=False, otp_sender=REAL_SENDER, otp_echo=False, tester_phones=())
        args.update(over)
        return check_sign_in(**args)

    def test_production_with_a_real_sender_and_no_echo_starts(self):
        self.check()

    def test_production_refuses_the_echo_without_tester_phones(self):
        with self.assertRaisesMessage(StartupError, "OTP_ECHO_IN_RESPONSE"):
            self.check(otp_echo=True)

    def test_production_refuses_the_console_sender_without_tester_phones(self):
        with self.assertRaisesMessage(StartupError, "console sender"):
            self.check(otp_sender=CONSOLE_SENDER)

    def test_closed_testing_allows_the_console_sender_and_the_echo(self):
        self.check(otp_sender=CONSOLE_SENDER, otp_echo=True, tester_phones=(LISTED,))

    def test_closed_testing_is_capped_at_ten_numbers(self):
        ten = tuple(f"+9198000000{i:02d}" for i in range(10))
        self.check(tester_phones=ten, otp_sender=CONSOLE_SENDER)
        with self.assertRaisesMessage(StartupError, "at most 10"):
            self.check(tester_phones=(*ten, "+919800000099"), otp_sender=CONSOLE_SENDER)

    def test_development_is_unrestricted(self):
        self.check(debug=True, otp_sender=CONSOLE_SENDER, otp_echo=True)
        self.check(debug=True, tester_phones=tuple(f"+9198000000{i:02d}" for i in range(20)))

    def test_a_console_sender_under_another_name_is_refused_too(self):
        alias = "apps.accounts.tests.test_closed_testing.QuietSender"
        with self.assertRaisesMessage(StartupError, "console sender"):
            check_sender_class(debug=False, tester_phones=(), otp_sender=alias)
        with self.assertRaisesMessage(StartupError, "cannot be imported"):
            check_sender_class(debug=False, tester_phones=(), otp_sender="no.such.Sender")
        with self.assertRaisesMessage(StartupError, "cannot be imported"):
            check_sender_class(debug=False, tester_phones=(), otp_sender="")
        # A real sender passes; development and closed testing are not checked.
        check_sender_class(debug=False, tester_phones=(), otp_sender=RECORDER)
        check_sender_class(debug=True, tester_phones=(), otp_sender=alias)
        check_sender_class(debug=False, tester_phones=(LISTED,), otp_sender=alias)

    def test_tester_phones_are_parsed_strictly(self):
        self.assertEqual(parse_tester_phones(""), ())
        self.assertEqual(parse_tester_phones(None), ())
        self.assertEqual(
            parse_tester_phones(" +919876543210 , +919812345678,,+919876543210 "),
            ("+919876543210", "+919812345678"),
        )
        for bad in ("9876543210", "+91 98765 43210", "+91abc", "+0123456789"):
            with self.assertRaisesMessage(StartupError, "E.164"):
                parse_tester_phones(bad)

    def test_warning_names_the_mode_and_the_count(self):
        self.assertIsNone(closed_testing_warning(()))
        one = closed_testing_warning((LISTED,))
        self.assertIn("CLOSED-TESTING SIGN-IN IS ACTIVE", one)
        self.assertIn("1 listed phone number ", one)
        self.assertIn("3 listed phone numbers", closed_testing_warning((LISTED, UNLISTED, "+919800000001")))

    def test_warning_is_logged_at_startup_only_in_closed_testing(self):
        from django.apps import apps

        config = apps.get_app_config("accounts")
        self.assertIsInstance(config, AccountsConfig)
        with override_settings(TESTER_PHONES=(LISTED, UNLISTED)):
            with self.assertLogs("forreal.startup", level="WARNING") as logs:
                config.ready()
        self.assertIn("2 listed phone numbers", logs.output[0])
        # The test runner switches DEBUG off, so this is the production path: a real sender is needed.
        with override_settings(TESTER_PHONES=(), OTP_SENDER=RECORDER):
            with self.assertNoLogs("forreal.startup", level="WARNING"):
                config.ready()


class RealStartupTests(SimpleTestCase):
    """Loads the real settings module in a fresh process, as a deployment would."""

    def start(self, **env):
        base = {k: v for k, v in os.environ.items() if k not in {"DEBUG", "OTP_SENDER", "OTP_ECHO_IN_RESPONSE", "TESTER_PHONES"}}
        base.update({"DEBUG": "0", "SECRET_KEY": "x" * 50, "DJANGO_SETTINGS_MODULE": "config.settings"})
        base.update(env)
        return subprocess.run(
            [sys.executable, "-c", "import django; django.setup(); from django.conf import settings; print(len(settings.TESTER_PHONES))"],
            env=base, capture_output=True, text=True, timeout=120, cwd=settings.BASE_DIR,
        )

    def test_echo_without_tester_phones_refuses_to_start(self):
        run = self.start(OTP_SENDER=RECORDER, OTP_ECHO_IN_RESPONSE="1")
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("OTP_ECHO_IN_RESPONSE is on with DEBUG off", run.stderr)

    def test_default_console_sender_refuses_to_start(self):
        run = self.start()
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("console sender with DEBUG off", run.stderr)

    def test_closed_testing_starts_with_console_sender_and_warns(self):
        run = self.start(TESTER_PHONES=f"{LISTED},{UNLISTED}", OTP_ECHO_IN_RESPONSE="1")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.strip(), "2")
        self.assertIn("CLOSED-TESTING SIGN-IN IS ACTIVE: only 2 listed phone numbers", run.stderr)

    def test_more_than_ten_tester_phones_refuses_to_start(self):
        eleven = ",".join(f"+9198000000{i:02d}" for i in range(11))
        run = self.start(TESTER_PHONES=eleven)
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("at most 10", run.stderr)

    def test_a_real_sender_without_tester_phones_starts_quietly(self):
        run = self.start(OTP_SENDER=RECORDER)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertNotIn("CLOSED-TESTING", run.stderr)

    def test_a_sender_that_cannot_be_imported_refuses_to_start(self):
        run = self.start(OTP_SENDER="sms.provider.Sender")
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("cannot be imported", run.stderr)
