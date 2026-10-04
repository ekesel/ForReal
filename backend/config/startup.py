"""Start-up rules for sign-in, kept out of settings.py so they can be tested.

Normal operation sends the one-time code by SMS through OTP_SENDER and never
returns it to the caller. Closed testing (TESTER_PHONES set) is the one exception:
only the listed numbers may sign in, and they get the code in the API response
instead of by SMS.
"""
import re

E164 = re.compile(r"^\+[1-9]\d{7,14}$")
CONSOLE_SENDER = "apps.accounts.otp.ConsoleOtpSender"
MAX_TESTER_PHONES = 10


class StartupError(RuntimeError):
    """The configuration is unsafe; the process must not start."""


def parse_tester_phones(raw):
    """Comma-separated E.164 numbers -> tuple without duplicates, in the order given."""
    phones = []
    for part in (raw or "").split(","):
        phone = part.strip()
        if not phone:
            continue
        if not E164.match(phone):
            raise StartupError(
                f"TESTER_PHONES: '{phone}' is not an E.164 number such as +919876543210."
            )
        if phone not in phones:
            phones.append(phone)
    return tuple(phones)


def check_sign_in(*, debug, otp_sender, otp_echo, tester_phones):
    """Refuse configurations that would let anyone sign in without receiving an SMS.

    Development (DEBUG on) is unrestricted. In production the console sender and the
    echoed code are allowed only in closed testing, and closed testing is capped at
    a handful of numbers so it cannot quietly become the real sign-in.
    """
    if debug:
        return
    if tester_phones:
        if len(tester_phones) > MAX_TESTER_PHONES:
            raise StartupError(
                f"TESTER_PHONES lists {len(tester_phones)} numbers; closed testing allows at most "
                f"{MAX_TESTER_PHONES}. For more users, configure a real SMS sender and remove TESTER_PHONES."
            )
        return
    if otp_echo:
        raise StartupError(
            "OTP_ECHO_IN_RESPONSE is on with DEBUG off: anyone could sign in as any phone number. "
            "Turn it off, or set TESTER_PHONES for closed testing."
        )
    if otp_sender == CONSOLE_SENDER:
        raise StartupError(
            "OTP_SENDER is the console sender with DEBUG off: no code would ever reach a user. "
            "Configure a real SMS sender, or set TESTER_PHONES for closed testing."
        )


def closed_testing_warning(tester_phones):
    """The line logged at start-up while closed testing is active, or None."""
    if not tester_phones:
        return None
    count = len(tester_phones)
    return (
        f"CLOSED-TESTING SIGN-IN IS ACTIVE: only {count} listed phone number{'' if count == 1 else 's'} "
        "can sign in, and the one-time code is returned in the API response instead of being sent by SMS. "
        "Remove TESTER_PHONES and configure a real SMS sender before any wider release."
    )


def check_sender_class(*, debug, tester_phones, otp_sender):
    """Second look at OTP_SENDER once Django's apps are loaded and it can be imported.

    The path comparison in check_sign_in only catches the console sender by its own
    name. This also catches a subclass or alias of it, and a path that does not import.
    """
    if debug or tester_phones:
        return
    from django.utils.module_loading import import_string

    from apps.accounts.otp import ConsoleOtpSender

    try:
        sender = import_string(otp_sender)
    except ImportError as exc:
        raise StartupError(
            f"OTP_SENDER '{otp_sender}' cannot be imported, so no sign-in code could be sent."
        ) from exc
    if isinstance(sender, type) and issubclass(sender, ConsoleOtpSender):
        raise StartupError(
            f"OTP_SENDER '{otp_sender}' is the console sender with DEBUG off: no code would ever reach "
            "a user. Configure a real SMS sender, or set TESTER_PHONES for closed testing."
        )
