from django.contrib.gis import admin

from .models import Category, Merchant, Payee, PayeeMerchantLink

admin.site.register(Category)


@admin.register(Payee)
class PayeeAdmin(admin.ModelAdmin):
    search_fields = ["normalized_name"]


@admin.register(Merchant)
class MerchantAdmin(admin.GISModelAdmin):
    list_display = ["name", "category", "locality", "is_online"]
    search_fields = ["name"]
    list_filter = ["category", "is_online"]


@admin.register(PayeeMerchantLink)
class LinkAdmin(admin.ModelAdmin):
    list_display = ["payee", "kind", "merchant", "created_at"]
    raw_id_fields = ["user", "payee", "merchant"]
