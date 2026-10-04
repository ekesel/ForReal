from django.contrib import admin

from .models import ParserTemplate


@admin.register(ParserTemplate)
class ParserTemplateAdmin(admin.ModelAdmin):
    list_display = ["name", "bank", "txn_type", "priority", "is_active", "updated_at"]
    list_filter = ["bank", "is_active"]
