from django.contrib.auth import get_user_model
from rest_framework_simplejwt.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.settings import api_settings


class RefreshSerializer(TokenRefreshSerializer):
    """Token refresh that answers 401 when the token's user no longer exists.

    simplejwt looks the user up with `.get()` and only handles the user being
    inactive; a deleted account raises DoesNotExist, which surfaces as a 500. A
    refresh token for an account that is gone or disabled is simply not valid any
    more. Both cases get the same 401 in simplejwt's usual error shape:
    {"detail": "...", "code": "no_active_account"}.
    """

    def validate(self, attrs):
        refresh = self.token_class(attrs["refresh"])
        user_id = refresh.payload.get(api_settings.USER_ID_CLAIM)
        if user_id is not None:
            user = get_user_model().objects.filter(**{api_settings.USER_ID_FIELD: user_id}).first()
            if user is None or not api_settings.USER_AUTHENTICATION_RULE(user):
                raise AuthenticationFailed(self.error_messages["no_active_account"], "no_active_account")
        return super().validate(attrs)
