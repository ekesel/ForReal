from django.db import migrations

HDFC_UPI_DEBIT = {
    "bank": "HDFC",
    "name": "HDFC UPI debit (Sent Rs)",
    "sender_ids": ["HDFCBK"],
    "source": "sms",
    "txn_type": "debit",
    "pattern": (
        r"Sent Rs\.(?<amount>[\d,]+(?:\.\d{1,2})?)\s+"
        r"From HDFC Bank A/C \*(?<account>\d{4})\s+"
        r"To (?<payee>.+?)\s+"
        r"On (?<date>\d{2}/\d{2}/\d{2})\s+"
        r"Ref (?<ref>\d+)"
    ),
    "flags": "s",
    "date_format": "dd/MM/yy",
    "sample": (
        "Sent Rs.300.00\nFrom HDFC Bank A/C *0000\nTo SAMPLE  PAYEE\nOn 02/08/26\nRef 000000000000\n"
        "Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808"
    ),
    "priority": 10,
}


def seed(apps, schema_editor):
    ParserTemplate = apps.get_model("parsers", "ParserTemplate")
    data = dict(HDFC_UPI_DEBIT)
    ParserTemplate.objects.get_or_create(name=data.pop("name"), defaults=data)


class Migration(migrations.Migration):
    dependencies = [("parsers", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
