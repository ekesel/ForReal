from django.db import transaction

from .models import REQUIRES, Consent, Purpose


class ConsentError(Exception):
    pass


def current_state(user) -> dict:
    state = {p.value: False for p in Purpose}
    for purpose, granted in Consent.objects.filter(user=user, is_current=True).values_list("purpose", "granted"):
        state[purpose] = granted
    return state


def has_consent(user, purpose) -> bool:
    return Consent.objects.filter(user=user, purpose=purpose, is_current=True, granted=True).exists()


def users_with_consent(purpose):
    """Subquery of user ids currently holding a consent. Use as user__in=..."""
    return Consent.objects.filter(purpose=purpose, is_current=True, granted=True).values("user_id")


def _record(user, purpose, granted, notice_version):
    Consent.objects.filter(user=user, purpose=purpose, is_current=True).update(is_current=False)
    return Consent.objects.create(user=user, purpose=purpose, granted=granted, notice_version=notice_version)


def _dependents(purpose):
    out = []
    for child, parent in REQUIRES.items():
        if parent == purpose:
            out.append(child)
            out.extend(_dependents(child))
    return out


@transaction.atomic
def set_consent(user, purpose, granted: bool, notice_version: str) -> dict:
    # Serialise changes per user so history stays consistent.
    type(user).objects.select_for_update().get(pk=user.pk)
    state = current_state(user)
    if granted:
        parent = REQUIRES.get(purpose)
        if parent and not state[parent]:
            raise ConsentError(f"'{purpose}' needs '{parent}' to be granted first.")
        if not state[purpose]:
            _record(user, purpose, True, notice_version)
    elif state[purpose]:
        for p in [purpose, *_dependents(purpose)]:
            if state[p]:
                _record(user, p, False, notice_version)
                _on_withdraw(user, p)
    return current_state(user)


def _on_withdraw(user, purpose):
    """Data effects of a withdrawal. Community purposes need none: eligibility is
    checked against current consent every time shared data is computed."""
    from apps.merchants.models import PayeeMerchantLink
    from apps.transactions.models import Transaction

    if purpose == Purpose.PRIVATE_ANALYTICS:
        Transaction.objects.filter(user=user).delete()
        PayeeMerchantLink.objects.filter(user=user).delete()
    elif purpose == Purpose.LOCATION:
        Transaction.objects.filter(user=user).update(location=None, locality=None)
        PayeeMerchantLink.objects.filter(user=user).update(location=None)
