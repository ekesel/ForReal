from rest_framework import status
from rest_framework.exceptions import APIException
from rest_framework.permissions import BasePermission

from .models import Purpose
from .services import has_consent


class ConsentRequired(APIException):
    """403 with a machine-readable code, so clients can tell a missing consent apart
    from any other 403: {"code": "...", "detail": "..."}."""

    status_code = status.HTTP_403_FORBIDDEN

    def __init__(self, code, message):
        super().__init__(detail={"code": code, "detail": message})


class _ConsentPermission(BasePermission):
    purpose = None
    code = None
    message = None

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if not has_consent(request.user, self.purpose):
            raise ConsentRequired(self.code, self.message)
        return True


class HasPrivateAnalyticsConsent(_ConsentPermission):
    purpose = Purpose.PRIVATE_ANALYTICS
    code = "consent_required"
    message = "Grant the 'private_analytics' consent before sending or reading payment data."


class HasLocationConsent(_ConsentPermission):
    purpose = Purpose.LOCATION
    # A different code: the payment consent is in place, only location is missing.
    code = "location_consent_required"
    message = "Grant the 'location' consent before sending a location."
