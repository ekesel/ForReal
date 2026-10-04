from django.shortcuts import get_object_or_404
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.pagination import CursorPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.consents.permissions import HasLocationConsent, HasPrivateAnalyticsConsent
from apps.merchants.serializers import MerchantSerializer

from . import services
from .models import Transaction
from .serializers import IngestBatchSerializer, LocationSerializer, TransactionSerializer


def _queryset(user):
    return (
        Transaction.objects.filter(user=user)
        .select_related("payee", "merchant__category")
        .prefetch_related("items__item")
    )


class IngestBatchView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def post(self, request):
        s = IngestBatchSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        results = services.ingest_batch(request.user, s.validated_data["transactions"])
        by_id = _queryset(request.user).in_bulk([r["transaction"].id for r in results])
        out = []
        for r in results:
            txn = by_id[r["transaction"].id]
            prompt = services.payee_prompt(txn)
            out.append(
                {
                    "status": r["status"],
                    "transaction": TransactionSerializer(txn).data,
                    # What the notification should ask: "payee", "items" or null.
                    "ask": prompt["ask"],
                    "payee_suggestions": MerchantSerializer(prompt["crowd"], many=True).data,
                }
            )
        return Response({"results": out})


class Pagination(CursorPagination):
    page_size = 50
    ordering = ("-occurred_on", "-created_at")


class TransactionListView(ListAPIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]
    serializer_class = TransactionSerializer
    pagination_class = Pagination

    def get_queryset(self):
        qs = _queryset(self.request.user)
        kind = self.request.query_params.get("kind")
        return qs.filter(kind=kind) if kind else qs


class TransactionDetailView(RetrieveAPIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]
    serializer_class = TransactionSerializer

    def get_queryset(self):
        return _queryset(self.request.user)


class TransactionLocationView(APIView):
    """Attach a location to a payment that was ingested without one. A payment that
    already has a location is returned unchanged."""

    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent, HasLocationConsent]

    def post(self, request, pk):
        txn = get_object_or_404(Transaction, pk=pk, user=request.user)
        s = LocationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        services.attach_location(txn, s.validated_data["lat"], s.validated_data["lng"])
        return Response(TransactionSerializer(_queryset(request.user).get(pk=txn.pk)).data)
