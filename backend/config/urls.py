from django.conf import settings
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health(_request):
    return JsonResponse({"status": "ok"})


api = [
    path("", include("apps.accounts.urls")),
    path("", include("apps.consents.urls")),
    path("", include("apps.merchants.urls")),
    path("", include("apps.transactions.urls")),
    path("", include("apps.tagging.urls")),
    path("", include("apps.parsers.urls")),
]

urlpatterns = [
    path(settings.ADMIN_PATH, admin.site.urls),
    path("health/", health),
    path("api/v1/", include(api)),
]
