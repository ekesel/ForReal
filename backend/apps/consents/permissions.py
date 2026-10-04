from rest_framework.permissions import BasePermission

from .models import Purpose
from .services import has_consent


class HasPrivateAnalyticsConsent(BasePermission):
    message = "Grant the 'private_analytics' consent before sending or reading payment data."
    code = "consent_required"

    def has_permission(self, request, view):
        return has_consent(request.user, Purpose.PRIVATE_ANALYTICS)
