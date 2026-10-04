import hashlib
import hmac
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from django.utils.module_loading import import_string

from .models import OtpChallenge

log = logging.getLogger(__name__)


class OtpError(Exception):
    def __init__(self, code, message):
        self.code, self.message = code, message
        super().__init__(message)


class ConsoleOtpSender:
    """Development sender: writes the code to the log instead of sending an SMS."""

    def send(self, phone: str, code: str) -> None:
        log.info("OTP for %s is %s", phone, code)


def _hash(phone: str, code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), f"{phone}:{code}".encode(), hashlib.sha256).hexdigest()


def closed_testing() -> bool:
    """True while sign-in is limited to the numbers in TESTER_PHONES."""
    return bool(settings.TESTER_PHONES)


def require_invited(phone: str) -> None:
    """In closed testing only listed numbers may ask for or use a code."""
    if closed_testing() and phone not in settings.TESTER_PHONES:
        raise OtpError("not_invited", "This number is not on the test list.")


def request_otp(phone: str) -> str:
    require_invited(phone)
    now = timezone.now()
    recent = OtpChallenge.objects.filter(phone=phone, created_at__gte=now - timedelta(hours=1)).count()
    if recent >= settings.OTP_MAX_REQUESTS_PER_HOUR:
        raise OtpError("too_many_requests", "Too many codes requested. Try again later.")
    code = f"{secrets.randbelow(10**6):06d}"
    # Only the newest code is valid.
    OtpChallenge.objects.filter(phone=phone, consumed_at__isnull=True).update(consumed_at=now)
    OtpChallenge.objects.create(
        phone=phone, code_hash=_hash(phone, code), expires_at=now + timedelta(seconds=settings.OTP_TTL_SECONDS)
    )
    if not closed_testing():
        import_string(settings.OTP_SENDER)().send(phone, code)
    # In closed testing nothing is sent or logged: the API response carries the code.
    return code


def verify_otp(phone: str, code: str) -> None:
    require_invited(phone)
    now = timezone.now()
    challenge = (
        OtpChallenge.objects.filter(phone=phone, consumed_at__isnull=True, expires_at__gt=now)
        .order_by("-created_at")
        .first()
    )
    if challenge is None:
        raise OtpError("expired", "Code expired or not requested.")
    if challenge.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise OtpError("too_many_attempts", "Too many wrong attempts. Request a new code.")
    if not hmac.compare_digest(challenge.code_hash, _hash(phone, code)):
        challenge.attempts += 1
        challenge.save(update_fields=["attempts"])
        raise OtpError("invalid", "Incorrect code.")
    challenge.consumed_at = now
    challenge.save(update_fields=["consumed_at"])
