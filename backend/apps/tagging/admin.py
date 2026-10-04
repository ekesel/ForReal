from django.contrib import admin

from .models import Item, ItemAlias, TagWeight, TransactionItem


class AliasInline(admin.TabularInline):
    model = ItemAlias
    extra = 1


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ["name", "category", "is_category_default", "is_verified"]
    list_filter = ["is_verified", "category"]
    search_fields = ["name"]
    inlines = [AliasInline]


@admin.register(TagWeight)
class TagWeightAdmin(admin.ModelAdmin):
    list_display = ["origin", "weight"]


@admin.register(TransactionItem)
class TransactionItemAdmin(admin.ModelAdmin):
    list_display = ["transaction", "item", "quantity", "origin", "confidence", "rejected_at"]
    list_filter = ["origin"]
    raw_id_fields = ["transaction"]
