"""ForReal backend settings. Everything environment-specific comes from env vars."""
import os
from datetime import timedelta
from pathlib import Path

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name, default=False):
    return os.environ.get(name, str(default)).lower() in ("1", "true", "yes")


DEBUG = env_bool("DEBUG", False)
SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-insecure-key" if DEBUG else "")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY must be set when DEBUG is off")

# Pepper for hashing UPI reference numbers. Changing it breaks de-duplication
# against already-stored transactions, so set it once per environment.
REF_HASH_PEPPER = os.environ.get("REF_HASH_PEPPER", SECRET_KEY)

ALLOWED_HOSTS = [h for h in os.environ.get("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",") if h]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.gis",
    "django.contrib.postgres",
    "rest_framework",
    "apps.common",
    "apps.accounts",
    "apps.consents",
    "apps.geo",
    "apps.merchants",
    "apps.transactions",
    "apps.tagging",
    "apps.parsers",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

DATABASES = {
    "default": dj_database_url.parse(
        os.environ.get("DATABASE_URL", "postgis://forreal:forreal@localhost:5432/forreal"),
        conn_max_age=60,
    )
}
DATABASES["default"]["ENGINE"] = "django.contrib.gis.db.backends.postgis"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "accounts.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
]

LANGUAGE_CODE = "en-in"
TIME_ZONE = "Asia/Kolkata"
USE_I18N = False
USE_TZ = True
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework_simplejwt.authentication.JWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"otp": os.environ.get("OTP_IP_THROTTLE", "30/hour")},
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=60),
    "ROTATE_REFRESH_TOKENS": True,
    "USER_ID_FIELD": "id",
}

# --- OTP -------------------------------------------------------------------
OTP_SENDER = os.environ.get("OTP_SENDER", "apps.accounts.otp.ConsoleOtpSender")
OTP_TTL_SECONDS = 300
OTP_MAX_ATTEMPTS = 5
OTP_MAX_REQUESTS_PER_HOUR = 5
# Returns the code in the API response. Development only.
OTP_ECHO_IN_RESPONSE = env_bool("OTP_ECHO_IN_RESPONSE", DEBUG)

# --- Product rules ---------------------------------------------------------
# Coordinates are rounded to this many decimals before storage (3 = ~110 m).
LOCATION_DECIMALS = 3
# Distinct users who must label a payee as the same shop before it is suggested to others.
CROWD_MIN_CONFIRMATIONS = int(os.environ.get("CROWD_MIN_CONFIRMATIONS", 2))
# A confirmation counts for a payer if it was made within this distance of them.
CROWD_MATCH_RADIUS_M = 500
# A new merchant is merged into an existing one with a similar name inside this radius.
MERCHANT_DEDUP_RADIUS_M = 300
MERCHANT_DEDUP_SIMILARITY = 0.6
# Distinct users who must confirm an item at a shop before it is suggested to others.
CROWD_TAG_MIN_USERS = int(os.environ.get("CROWD_TAG_MIN_USERS", 2))
# After this many confirmations of the same item at the same payee, stop prompting.
AUTO_TAG_AFTER_CONFIRMATIONS = 3
INGEST_MAX_BATCH = 200
LOCALITY_FALLBACK_RADIUS_M = 3000

# --- Geocoding -------------------------------------------------------------
# Dotted path to the reverse geocoder that names new localities.
# apps.geo.geocoding.NullGeocoder switches geocoding off.
GEOCODER_BACKEND = os.environ.get("GEOCODER_BACKEND", "apps.geo.geocoding.NominatimGeocoder")
NOMINATIM_BASE_URL = os.environ.get("NOMINATIM_BASE_URL", "https://nominatim.openstreetmap.org")
# Required by the Nominatim usage policy, e.g. "ForReal/0.1 (you@example.com)".
# No request is sent while this is empty.
NOMINATIM_USER_AGENT = os.environ.get("NOMINATIM_USER_AGENT", "")
# For the future GoogleGeocoder. Unused for now.
GOOGLE_MAPS_API_KEY = os.environ.get("GOOGLE_MAPS_API_KEY", "")

# --- Celery ----------------------------------------------------------------
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
CELERY_BROKER_URL = REDIS_URL
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
CELERY_TASK_ALWAYS_EAGER = env_bool("CELERY_TASK_ALWAYS_EAGER", False)
CELERY_BEAT_SCHEDULE = {
    "purge-expired-otps": {"task": "apps.accounts.tasks.purge_expired_otps", "schedule": 3600},
}

if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
