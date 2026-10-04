from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .models import Consent, Purpose


class ConsentChangeSerializer(serializers.Serializer):
    purpose = serializers.ChoiceField(choices=Purpose.choices)
    granted = serializers.BooleanField()
    notice_version = serializers.CharField(max_length=20)


class ConsentView(APIView):
    def get(self, request):
        return Response({"consents": services.current_state(request.user)})

    def post(self, request):
        s = ConsentChangeSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        try:
            state = services.set_consent(request.user, **s.validated_data)
        except services.ConsentError as e:
            return Response({"code": "dependency", "detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"consents": state})


class ConsentHistoryView(APIView):
    def get(self, request):
        rows = Consent.objects.filter(user=request.user).order_by("created_at", "id")
        return Response({"history": list(rows.values("purpose", "granted", "notice_version", "created_at"))})
