from rest_framework import serializers

from .models import Device, User, normalize_phone, phone_validator


class PhoneField(serializers.CharField):
    def to_internal_value(self, data):
        phone = normalize_phone(super().to_internal_value(data))
        phone_validator(phone)
        return phone


class OtpRequestSerializer(serializers.Serializer):
    phone = PhoneField(max_length=20)


class OtpVerifySerializer(serializers.Serializer):
    phone = PhoneField(max_length=20)
    code = serializers.RegexField(r"^\d{6}$")


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "phone", "display_name", "created_at"]
        read_only_fields = ["id", "phone", "created_at"]


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = ["device_id", "platform", "app_version", "push_token", "last_seen_at"]
        read_only_fields = ["last_seen_at"]
