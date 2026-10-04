from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from apps.common.geo import LatLngMixin, point_to_dict
from apps.merchants.serializers import MerchantSerializer
from apps.tagging.serializers import TransactionItemSerializer

from .models import AmountBand, DayPart, Source, Transaction

# Data the server must never receive (NFR-1 to NFR-3). Sending any of it is a client bug.
FORBIDDEN_FIELDS = {"amount", "raw_text", "sms_body", "body", "message", "balance", "account", "account_last4", "vpa"}


class IngestRowSerializer(LatLngMixin):
    client_txn_id = serializers.UUIDField()
    payee_name = serializers.CharField(max_length=140)
    occurred_on = serializers.DateField()
    day_part = serializers.ChoiceField(choices=DayPart.choices, required=False, allow_blank=True)
    amount_band = serializers.ChoiceField(choices=AmountBand.choices)
    source = serializers.ChoiceField(choices=Source.choices)
    ref = serializers.CharField(max_length=40, required=False, allow_blank=True)

    def to_internal_value(self, data):
        if isinstance(data, dict):
            leaked = FORBIDDEN_FIELDS.intersection(data)
            if leaked:
                raise serializers.ValidationError(
                    {name: "This field must stay on the device and is not accepted." for name in sorted(leaked)}
                )
        return super().to_internal_value(data)

    def validate_occurred_on(self, value):
        if value > timezone.localdate() + timedelta(days=1):
            raise serializers.ValidationError("Date is in the future.")
        return value


class IngestBatchSerializer(serializers.Serializer):
    transactions = IngestRowSerializer(many=True, allow_empty=False)

    def validate_transactions(self, rows):
        if len(rows) > settings.INGEST_MAX_BATCH:
            raise serializers.ValidationError(f"At most {settings.INGEST_MAX_BATCH} transactions per batch.")
        return rows


class LocationSerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)


class TransactionSerializer(serializers.ModelSerializer):
    payee = serializers.SerializerMethodField()
    merchant = MerchantSerializer(read_only=True)
    items = serializers.SerializerMethodField()
    location = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            "id", "client_txn_id", "payee", "merchant", "kind", "occurred_on", "day_part",
            "amount_band", "sources", "location", "items", "created_at",
        ]

    def get_payee(self, obj):
        return {"id": obj.payee_id, "name": obj.payee.display_name}

    def get_location(self, obj):
        return point_to_dict(obj.location)

    def get_items(self, obj):
        active = [ti for ti in obj.items.all() if ti.rejected_at is None]
        return TransactionItemSerializer(active, many=True).data
