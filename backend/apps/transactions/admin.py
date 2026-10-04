from django.contrib import admin

from .models import Transaction


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ["id", "payee", "merchant", "kind", "occurred_on", "amount_band", "sources"]
    list_filter = ["kind", "amount_band"]
    raw_id_fields = ["user", "payee", "merchant"]
    exclude = ["location"]
