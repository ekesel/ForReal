import re

_WS = re.compile(r"\s+")


def normalize_name(value: str) -> str:
    """Canonical form for payee and merchant names: upper case, single spaces."""
    return _WS.sub(" ", value or "").strip().upper()


def normalize_item(value: str) -> str:
    return _WS.sub(" ", value or "").strip().lower()
