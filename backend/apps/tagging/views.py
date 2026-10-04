from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.text import normalize_item
from apps.consents.permissions import HasPrivateAnalyticsConsent
from apps.transactions.models import Transaction

from . import services
from .models import Item
from .serializers import ItemSerializer, SetItemsSerializer, TransactionItemSerializer


def _txn(request, pk):
    return get_object_or_404(Transaction.objects.select_related("merchant", "payee", "user"), pk=pk, user=request.user)


def _error(e):
    return Response({"code": "not_taggable", "detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)


class ItemSearchView(APIView):
    """Chips for the 'Something else' screen: ?category=bakery and/or ?q=cak"""

    def get(self, request):
        qs = Item.objects.select_related("category")
        category, q = request.query_params.get("category"), request.query_params.get("q")
        if category:
            qs = qs.filter(Q(category__slug=category) | Q(category__isnull=True))
        if q:
            norm = normalize_item(q)
            qs = qs.filter(Q(name__icontains=norm) | Q(aliases__alias__startswith=norm)).distinct()
        return Response({"items": ItemSerializer(qs[:50], many=True).data})


class SuggestionsView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def get(self, request, pk):
        txn = _txn(request, pk)
        out = [
            {"item": ItemSerializer(s["item"]).data, "quantity": s["quantity"], "origin": s["origin"], "confidence": s["confidence"]}
            for s in services.suggest_items(txn)
        ]
        return Response({"suggestions": out, "should_prompt": services.should_prompt(txn)})


class TransactionItemsView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def put(self, request, pk):
        txn = _txn(request, pk)
        s = SetItemsSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        try:
            items = services.set_user_items(txn, s.validated_data["items"], request.user)
        except services.TaggingError as e:
            return _error(e)
        return Response({"items": TransactionItemSerializer(items, many=True).data})


class ConfirmItemsView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def post(self, request, pk):
        txn = _txn(request, pk)
        try:
            items = services.confirm_items(txn)
        except services.TaggingError as e:
            return _error(e)
        return Response({"items": TransactionItemSerializer(items, many=True).data})
