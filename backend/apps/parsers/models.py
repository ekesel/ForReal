import re

from django.contrib.postgres.fields import ArrayField
from django.core.exceptions import ValidationError
from django.db import models

REQUIRED_GROUPS = {"amount", "payee"}


def compile_pattern(pattern: str, flags: str = ""):
    """Patterns are stored in the Dart/JavaScript dialect, (?<name>...), because the app
    runs them. Python needs (?P<name>...), so convert before compiling here."""
    py = re.sub(r"\(\?<(?![=!])", "(?P<", pattern)
    f = 0
    if "s" in flags:
        f |= re.DOTALL
    if "i" in flags:
        f |= re.IGNORECASE
    return re.compile(py, f)


class ParserTemplate(models.Model):
    """One bank message shape. The app downloads these, so a bank changing its SMS
    wording is fixed here without an app release."""

    class TxnType(models.TextChoices):
        DEBIT = "debit"
        CREDIT = "credit"  # recognised so the app can ignore it

    bank = models.CharField(max_length=40)
    name = models.CharField(max_length=80, unique=True)
    sender_ids = ArrayField(models.CharField(max_length=20), help_text="SMS sender codes, e.g. HDFCBK")
    source = models.CharField(max_length=10, default="sms")
    txn_type = models.CharField(max_length=10, choices=TxnType.choices, default=TxnType.DEBIT)
    pattern = models.TextField(help_text="Regex with named groups: amount, payee, and optionally date, ref, account")
    flags = models.CharField(max_length=4, blank=True, help_text="s = dot matches newline, i = ignore case")
    date_format = models.CharField(max_length=20, blank=True, help_text="e.g. dd/MM/yy")
    sample = models.TextField(blank=True, help_text="A message this pattern must match (numbers changed)")
    priority = models.PositiveSmallIntegerField(default=100, help_text="Lower is tried first")
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["priority", "id"]

    def __str__(self):
        return self.name

    def clean(self):
        try:
            rx = compile_pattern(self.pattern, self.flags)
        except re.error as e:
            raise ValidationError({"pattern": f"Invalid regex: {e}"})
        missing = REQUIRED_GROUPS - set(rx.groupindex)
        if missing:
            raise ValidationError({"pattern": f"Missing named groups: {', '.join(sorted(missing))}"})
        if self.sample and not rx.search(self.sample):
            raise ValidationError({"sample": "The pattern does not match the sample message."})
