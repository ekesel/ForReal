from django.conf import settings
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from . import otp, services
from .models import Device, User
from .serializers import DeviceSerializer, OtpRequestSerializer, OtpVerifySerializer, UserSerializer


class OtpRequestView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_scope = "otp"

    def post(self, request):
        s = OtpRequestSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        try:
            code = otp.request_otp(s.validated_data["phone"])
        except otp.OtpError as e:
            return Response({"code": e.code, "detail": e.message}, status=status.HTTP_429_TOO_MANY_REQUESTS)
        body = {"detail": "Code sent.", "expires_in": settings.OTP_TTL_SECONDS}
        if settings.OTP_ECHO_IN_RESPONSE:
            body["debug_code"] = code
        return Response(body)


class OtpVerifyView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_scope = "otp"

    def post(self, request):
        s = OtpVerifySerializer(data=request.data)
        s.is_valid(raise_exception=True)
        phone = s.validated_data["phone"]
        try:
            otp.verify_otp(phone, s.validated_data["code"])
        except otp.OtpError as e:
            return Response({"code": e.code, "detail": e.message}, status=status.HTTP_400_BAD_REQUEST)
        user = User.objects.filter(phone=phone).first()
        is_new = user is None
        if is_new:
            user = User.objects.create_user(phone)
        if not user.is_active:
            return Response({"code": "inactive", "detail": "Account disabled."}, status=status.HTTP_403_FORBIDDEN)
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "is_new_user": is_new,
                "user": UserSerializer(user).data,
            }
        )


class MeView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        s = UserSerializer(request.user, data=request.data, partial=True)
        s.is_valid(raise_exception=True)
        s.save()
        return Response(s.data)

    def delete(self, request):
        services.delete_account(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ExportView(APIView):
    def get(self, request):
        return Response(services.export_user_data(request.user))


class DeviceView(APIView):
    """Register or refresh this install (push token, app version)."""

    def put(self, request):
        s = DeviceSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        data = dict(s.validated_data)
        device, _ = Device.objects.update_or_create(
            user=request.user, device_id=data.pop("device_id"), defaults=data
        )
        return Response(DeviceSerializer(device).data)
