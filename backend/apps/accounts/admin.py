from django.contrib import admin

from .models import Device, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ["phone", "display_name", "is_staff", "created_at"]
    search_fields = ["phone"]
    exclude = ["password"]


admin.site.register(Device)
