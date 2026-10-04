from django.contrib.gis import admin

from .models import Locality

admin.site.register(Locality, admin.GISModelAdmin)
