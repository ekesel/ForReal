from rest_framework import serializers

from apps.common.geo import LatLngMixin, point_to_dict

from .models import Category, Merchant, PayeeMerchantLink


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ["slug", "name"]


class MerchantSerializer(serializers.ModelSerializer):
    category = serializers.SlugRelatedField(slug_field="slug", read_only=True)
    location = serializers.SerializerMethodField()

    class Meta:
        model = Merchant
        fields = ["id", "name", "category", "is_online", "location"]

    def get_location(self, obj):
        return point_to_dict(obj.location)


class NewMerchantSerializer(LatLngMixin):
    name = serializers.CharField(max_length=120)
    category = serializers.SlugRelatedField(slug_field="slug", queryset=Category.objects.all())
    is_online = serializers.BooleanField(default=False)


class ResolvePayeeSerializer(LatLngMixin):
    """lat/lng at the top level is where the user is now; it places the confirmation
    for crowd matching. A new merchant may carry its own lat/lng."""

    kind = serializers.ChoiceField(choices=PayeeMerchantLink.Kind.choices)
    merchant_id = serializers.PrimaryKeyRelatedField(
        queryset=Merchant.objects.all(), required=False, allow_null=True, source="merchant"
    )
    new_merchant = NewMerchantSerializer(required=False)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        has_existing = attrs.get("merchant") is not None
        has_new = "new_merchant" in attrs
        if attrs["kind"] == PayeeMerchantLink.Kind.PERSON:
            if has_existing or has_new:
                raise serializers.ValidationError("A person cannot have a merchant.")
        elif has_existing == has_new:
            raise serializers.ValidationError("Send exactly one of merchant_id or new_merchant.")
        return attrs
