from django.contrib.gis import admin

from .models import GeocodeCell, Locality

admin.site.register(Locality, admin.GISModelAdmin)


@admin.register(GeocodeCell)
class GeocodeCellAdmin(admin.ModelAdmin):
    """Read-only view of the reverse-geocoding cache."""

    list_display = ["lat", "lng", "status", "provider", "locality", "created_at"]
    list_filter = ["status", "provider"]
    list_select_related = ["locality"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
