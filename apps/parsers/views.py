from django.db.models import Max
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ParserTemplate

FIELDS = ["id", "bank", "name", "sender_ids", "source", "txn_type", "pattern", "flags", "date_format", "priority"]


class ParserTemplateView(APIView):
    """Active templates plus a version number. The app re-downloads when the version changes."""

    def get(self, request):
        latest = ParserTemplate.objects.aggregate(v=Max("updated_at"))["v"]
        version = int(latest.timestamp()) if latest else 0
        if request.query_params.get("version") == str(version):
            return Response({"version": version, "changed": False})
        templates = list(ParserTemplate.objects.filter(is_active=True).values(*FIELDS))
        return Response({"version": version, "changed": True, "templates": templates})
