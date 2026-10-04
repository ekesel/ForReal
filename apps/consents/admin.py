from django.contrib import admin

from .models import Consent


@admin.register(Consent)
class ConsentAdmin(admin.ModelAdmin):
    list_display = ["user", "purpose", "granted", "is_current", "notice_version", "created_at"]
    list_filter = ["purpose", "granted", "is_current"]

    def has_change_permission(self, request, obj=None):
        return False
