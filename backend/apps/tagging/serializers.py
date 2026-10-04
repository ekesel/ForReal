from rest_framework import serializers

from .models import Item, TransactionItem


class ItemSerializer(serializers.ModelSerializer):
    category = serializers.SlugRelatedField(slug_field="slug", read_only=True)

    class Meta:
        model = Item
        fields = ["id", "name", "category"]


class TransactionItemSerializer(serializers.ModelSerializer):
    item = ItemSerializer(read_only=True)
    inferred = serializers.SerializerMethodField()

    class Meta:
        model = TransactionItem
        fields = ["item", "quantity", "origin", "confidence", "inferred"]

    def get_inferred(self, obj):
        # True means show it as a guess ("Tea, guessed").
        return obj.origin != "user"


class ItemEntrySerializer(serializers.Serializer):
    item_id = serializers.PrimaryKeyRelatedField(queryset=Item.objects.all(), required=False, source="item")
    name = serializers.CharField(max_length=60, required=False)
    quantity = serializers.IntegerField(min_value=1, max_value=99, default=1)

    def validate(self, attrs):
        if ("item" in attrs) == ("name" in attrs):
            raise serializers.ValidationError("Send exactly one of item_id or name.")
        return attrs


class SetItemsSerializer(serializers.Serializer):
    items = ItemEntrySerializer(many=True, allow_empty=False, max_length=20)
