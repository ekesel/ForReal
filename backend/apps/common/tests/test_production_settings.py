"""Production settings: required values, the admin path, proxy and cookie security."""
import json
import os
import subprocess
import sys

from django.conf import settings
from django.test import SimpleTestCase

from config.startup import StartupError, check_production, normalise_admin_path

SECRET = "s" * 50
PEPPER = "p" * 50
DB = "postgis://forreal:forreal@db:5432/forreal"
GOOD = dict(debug=False, secret_key=SECRET, ref_hash_pepper=PEPPER, allowed_hosts=["api.example.com"], database_url=DB)

PROBE = """
import json, django
django.setup()
from django.conf import settings
from django.urls import reverse
names = ["DEBUG", "ALLOWED_HOSTS", "CSRF_TRUSTED_ORIGINS", "ADMIN_PATH", "SECURE_SSL_REDIRECT",
         "SECURE_HSTS_SECONDS", "SECURE_PROXY_SSL_HEADER", "SESSION_COOKIE_SECURE", "CSRF_COOKIE_SECURE",
         "STATIC_URL"]
out = {n: getattr(settings, n) for n in names}
out["STATIC_ROOT"] = str(settings.STATIC_ROOT)
out["DB_HOST"] = settings.DATABASES["default"]["HOST"]
out["DB_ENGINE"] = settings.DATABASES["default"]["ENGINE"]
out["PEPPER_IS_SECRET"] = settings.REF_HASH_PEPPER == settings.SECRET_KEY
out["admin_index"] = reverse("admin:index")
print(json.dumps(out))
"""

MANAGED = {
    "DEBUG", "SECRET_KEY", "REF_HASH_PEPPER", "ALLOWED_HOSTS", "DATABASE_URL", "CSRF_TRUSTED_ORIGINS",
    "ADMIN_PATH", "STATIC_ROOT", "SECURE_HSTS_SECONDS", "OTP_SENDER", "OTP_ECHO_IN_RESPONSE", "TESTER_PHONES",
}


class ProductionCheckTests(SimpleTestCase):
    def refusal(self, **changes):
        with self.assertRaises(StartupError) as caught:
            check_production(**{**GOOD, **changes})
        return str(caught.exception)

    def test_complete_production_settings_start(self):
        check_production(**GOOD)

    def test_development_needs_none_of_them(self):
        check_production(debug=True, secret_key="dev", ref_hash_pepper="", allowed_hosts=[], database_url="")

    def test_secret_key_must_be_set_and_long(self):
        self.assertIn("SECRET_KEY", self.refusal(secret_key=""))
        self.assertIn("at least 50", self.refusal(secret_key="s" * 49))

    def test_pepper_must_be_set_and_differ_from_the_secret_key(self):
        self.assertIn("REF_HASH_PEPPER must be set", self.refusal(ref_hash_pepper=""))
        self.assertIn("different from SECRET_KEY", self.refusal(ref_hash_pepper=SECRET))

    def test_allowed_hosts_and_database_url_must_be_set(self):
        self.assertIn("ALLOWED_HOSTS", self.refusal(allowed_hosts=[]))
        self.assertIn("DATABASE_URL", self.refusal(database_url=""))

    def test_every_problem_is_reported_together(self):
        message = self.refusal(secret_key="", ref_hash_pepper="", allowed_hosts=[], database_url="")
        for name in ("SECRET_KEY", "REF_HASH_PEPPER", "ALLOWED_HOSTS", "DATABASE_URL"):
            self.assertIn(name, message)

    def test_admin_path_is_normalised(self):
        self.assertEqual(normalise_admin_path("admin/"), "admin/")
        self.assertEqual(normalise_admin_path(""), "admin/")
        self.assertEqual(normalise_admin_path("/back-office"), "back-office/")
        self.assertEqual(normalise_admin_path("ops/console/"), "ops/console/")
        for bad in ("<int:x>/", "a b/", "a//b", "^admin"):
            with self.assertRaises(StartupError):
                normalise_admin_path(bad)


class RealSettingsTests(SimpleTestCase):
    """Loads the real settings module in a fresh process, as a deployment would."""

    PRODUCTION = {
        "DEBUG": "0", "SECRET_KEY": SECRET, "REF_HASH_PEPPER": PEPPER, "ALLOWED_HOSTS": "api.example.com",
        "DATABASE_URL": DB, "TESTER_PHONES": "+919876543210",
    }

    def run_settings(self, **env):
        base = {k: v for k, v in os.environ.items() if k not in MANAGED}
        base["DJANGO_SETTINGS_MODULE"] = "config.settings"
        base.update(env)
        return subprocess.run(
            [sys.executable, "-c", PROBE], env=base, capture_output=True, text=True, timeout=120,
            cwd=settings.BASE_DIR,
        )

    def loaded(self, **env):
        run = self.run_settings(**env)
        self.assertEqual(run.returncode, 0, run.stderr)
        return json.loads(run.stdout.strip().splitlines()[-1])

    def refused(self, **env):
        run = self.run_settings(**env)
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("Refusing to start with DEBUG off", run.stderr)
        return run.stderr

    def without(self, name):
        return {k: v for k, v in self.PRODUCTION.items() if k != name}

    def test_development_defaults_are_unchanged(self):
        got = self.loaded(DEBUG="1")
        self.assertTrue(got["DEBUG"])
        self.assertEqual(got["ALLOWED_HOSTS"], ["localhost", "127.0.0.1"])
        self.assertEqual(got["CSRF_TRUSTED_ORIGINS"], [])
        self.assertEqual(got["ADMIN_PATH"], "admin/")
        self.assertEqual(got["admin_index"], "/admin/")
        self.assertEqual(got["DB_HOST"], "localhost")
        self.assertEqual(got["STATIC_URL"], "/static/")
        self.assertEqual(got["STATIC_ROOT"], str(settings.BASE_DIR / "staticfiles"))
        self.assertTrue(got["PEPPER_IS_SECRET"])
        self.assertFalse(got["SECURE_SSL_REDIRECT"])
        self.assertEqual(got["SECURE_HSTS_SECONDS"], 0)
        self.assertIsNone(got["SECURE_PROXY_SSL_HEADER"])
        self.assertFalse(got["SESSION_COOKIE_SECURE"])
        self.assertFalse(got["CSRF_COOKIE_SECURE"])

    def test_production_turns_on_https_redirect_hsts_and_secure_cookies(self):
        got = self.loaded(**self.PRODUCTION)
        self.assertFalse(got["DEBUG"])
        self.assertTrue(got["SECURE_SSL_REDIRECT"])
        self.assertEqual(got["SECURE_HSTS_SECONDS"], 31536000)
        self.assertEqual(got["SECURE_PROXY_SSL_HEADER"], ["HTTP_X_FORWARDED_PROTO", "https"])
        self.assertTrue(got["SESSION_COOKIE_SECURE"])
        self.assertTrue(got["CSRF_COOKIE_SECURE"])
        self.assertEqual(got["ALLOWED_HOSTS"], ["api.example.com"])
        self.assertEqual(got["DB_HOST"], "db")
        self.assertEqual(got["DB_ENGINE"], "django.contrib.gis.db.backends.postgis")
        self.assertFalse(got["PEPPER_IS_SECRET"])

    def test_hsts_duration_comes_from_the_environment(self):
        self.assertEqual(self.loaded(**self.PRODUCTION, SECURE_HSTS_SECONDS="300")["SECURE_HSTS_SECONDS"], 300)

    def test_csrf_trusted_origins_come_from_the_environment(self):
        got = self.loaded(**self.PRODUCTION, CSRF_TRUSTED_ORIGINS="https://api.example.com, https://b.example.com")
        self.assertEqual(got["CSRF_TRUSTED_ORIGINS"], ["https://api.example.com", "https://b.example.com"])

    def test_admin_moves_to_admin_path(self):
        got = self.loaded(**self.PRODUCTION, ADMIN_PATH="back-office")
        self.assertEqual(got["ADMIN_PATH"], "back-office/")
        self.assertEqual(got["admin_index"], "/back-office/")

    def test_static_root_comes_from_the_environment(self):
        self.assertEqual(self.loaded(**self.PRODUCTION, STATIC_ROOT="/srv/static")["STATIC_ROOT"], "/srv/static")

    def test_production_refuses_a_missing_or_short_secret_key(self):
        self.assertNotEqual(self.run_settings(**self.without("SECRET_KEY")).returncode, 0)
        self.assertIn("SECRET_KEY", self.refused(**{**self.PRODUCTION, "SECRET_KEY": "short"}))

    def test_production_refuses_a_missing_or_reused_pepper(self):
        self.assertIn("REF_HASH_PEPPER must be set", self.refused(**self.without("REF_HASH_PEPPER")))
        self.assertIn("different from SECRET_KEY", self.refused(**{**self.PRODUCTION, "REF_HASH_PEPPER": SECRET}))

    def test_production_refuses_missing_allowed_hosts(self):
        self.assertIn("ALLOWED_HOSTS", self.refused(**self.without("ALLOWED_HOSTS")))

    def test_production_refuses_a_missing_database_url(self):
        self.assertIn("DATABASE_URL", self.refused(**self.without("DATABASE_URL")))
