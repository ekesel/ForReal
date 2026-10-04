from django.db.models import Count, Max
from django.shortcuts import get_object_or_404
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.geo import LatLngMixin, coarse_point
from apps.consents.models import Purpose
from apps.consents.permissions import HasPrivateAnalyticsConsent
from apps.consents.services import has_consent
from rest_framework.permissions import IsAuthenticated

from . import services
from .models import Category, Payee, PayeeMerchantLink
from .serializers import CategorySerializer, MerchantSerializer, ResolvePayeeSerializer


def _point(request, data):
    """Location is used only while the user holds the location consent."""
    if data.get("lat") is None or not has_consent(request.user, Purpose.LOCATION):
        return None
    return coarse_point(data["lat"], data["lng"])


def _own_payee(request, pk):
    """Users can only act on payees they have paid."""
    return get_object_or_404(Payee.objects.filter(transactions__user=request.user).distinct(), pk=pk)


class CategoryListView(APIView):
    def get(self, request):
        return Response({"categories": CategorySerializer(Category.objects.all(), many=True).data})


class PendingPayeesView(APIView):
    """Payees the user has paid but not yet labelled as shop or person."""

    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def get(self, request):
        rows = (
            Payee.objects.filter(transactions__user=request.user, transactions__kind="unknown")
            .annotate(payments=Count("transactions"), last_paid=Max("transactions__occurred_on"))
            .order_by("-last_paid")
        )
        return Response(
            {
                "payees": [
                    {"id": p.id, "name": p.display_name, "payments": p.payments, "last_paid": p.last_paid}
                    for p in rows
                ]
            }
        )


class PayeeSuggestionsView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def get(self, request, pk):
        payee = _own_payee(request, pk)
        q = LatLngMixin(data=request.query_params)
        q.is_valid(raise_exception=True)
        point = _point(request, q.validated_data)
        crowd = services.crowd_suggestions(payee, point, exclude_user=request.user)
        return Response({"payee": {"id": payee.id, "name": payee.display_name}, "crowd": MerchantSerializer(crowd, many=True).data})


class ResolvePayeeView(APIView):
    permission_classes = [IsAuthenticated, HasPrivateAnalyticsConsent]

    def post(self, request, pk):
        payee = _own_payee(request, pk)
        s = ResolvePayeeSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        data = s.validated_data
        here = _point(request, data)
        merchant = data.get("merchant")
        if "new_merchant" in data:
            nm = data["new_merchant"]
            merchant = services.find_or_create_merchant(
                request.user, nm["name"], nm["category"], point=_point(request, nm) or here, is_online=nm["is_online"]
            )
        link = services.resolve_payee(request.user, payee, data["kind"], merchant=merchant, point=here)
        return Response(
            {
                "payee": {"id": payee.id, "name": payee.display_name},
                "kind": link.kind,
                "merchant": MerchantSerializer(link.merchant).data if link.merchant else None,
            }
        )


class MerchantSearchQuery(LatLngMixin):
    q = serializers.CharField(min_length=2, max_length=60)


class MerchantSearchView(APIView):
    def get(self, request):
        s = MerchantSearchQuery(data=request.query_params)
        s.is_valid(raise_exception=True)
        found = services.search_merchants(s.validated_data["q"], _point(request, s.validated_data))
        return Response({"merchants": MerchantSerializer(found, many=True).data})
