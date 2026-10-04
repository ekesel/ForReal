from django.db import migrations

# (name, category slug, is the category's default guess, aliases)
ITEMS = [
    ("Tea", "tea-stall", True, ["chai", "chaa", "cutting chai"]),
    ("Coffee", "tea-stall", False, []),
    ("Samosa", "food", False, ["samosas"]),
    ("Meal", "food", True, ["lunch", "dinner", "thali", "food"]),
    ("Momos", "food", False, ["momo"]),
    ("Snacks", "food", False, ["snack", "namkeen"]),
    ("Juice", "food", False, []),
    ("Cake", "bakery", True, ["cakes"]),
    ("Pastry", "bakery", False, ["pastries"]),
    ("Bread", "bakery", False, []),
    ("Biscuits", "bakery", False, ["biscuit"]),
    ("Groceries", "grocery", True, ["ration", "kirana", "grocery"]),
    ("Milk", "dairy", True, ["doodh"]),
    ("Vegetables", "fruits-vegetables", True, ["sabzi", "veggies"]),
    ("Fruits", "fruits-vegetables", False, ["fruit"]),
    ("Haircut", "salon", True, []),
    ("Petrol", "fuel", True, []),
    ("Diesel", "fuel", False, []),
    ("Medicine", "pharmacy", True, ["medicines", "dawai"]),
    ("Ride", "transport", True, ["cab", "auto", "bike taxi"]),
    ("Paan", "paan-shop", True, []),
    ("Cigarette", "paan-shop", False, ["cigarettes"]),
]

WEIGHTS = {"user": 1.0, "ai_own_history": 0.8, "ai_crowd": 0.6, "ai_category": 0.3, "ai_llm": 0.2}


def seed(apps, schema_editor):
    Category = apps.get_model("merchants", "Category")
    Item = apps.get_model("tagging", "Item")
    ItemAlias = apps.get_model("tagging", "ItemAlias")
    TagWeight = apps.get_model("tagging", "TagWeight")
    cats = {c.slug: c for c in Category.objects.all()}
    for name, cat, default, aliases in ITEMS:
        item, _ = Item.objects.get_or_create(
            slug=name.lower(),
            defaults={"name": name, "category": cats[cat], "is_category_default": default, "is_verified": True},
        )
        for alias in [name.lower(), *aliases]:
            ItemAlias.objects.get_or_create(alias=alias, defaults={"item": item})
    for origin, weight in WEIGHTS.items():
        TagWeight.objects.get_or_create(origin=origin, defaults={"weight": weight})


class Migration(migrations.Migration):
    dependencies = [("tagging", "0001_initial"), ("merchants", "0002_seed_categories")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
