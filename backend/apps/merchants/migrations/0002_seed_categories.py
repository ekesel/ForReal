from django.db import migrations

CATEGORIES = [
    ("tea-stall", "Tea stall"), ("food", "Food and restaurants"), ("bakery", "Bakery"),
    ("grocery", "Grocery and kirana"), ("dairy", "Dairy"), ("fruits-vegetables", "Fruits and vegetables"),
    ("salon", "Salon"), ("fuel", "Fuel"), ("pharmacy", "Pharmacy"), ("transport", "Transport"),
    ("paan-shop", "Paan shop"), ("stationery", "Stationery"), ("electronics", "Electronics"),
    ("clothing", "Clothing"), ("other", "Other"),
]


def seed(apps, schema_editor):
    Category = apps.get_model("merchants", "Category")
    for slug, name in CATEGORIES:
        Category.objects.get_or_create(slug=slug, defaults={"name": name})


class Migration(migrations.Migration):
    dependencies = [("merchants", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
