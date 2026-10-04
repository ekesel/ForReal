from django.conf import settings
from django.contrib.gis.geos import Point
from rest_framework import serializers


def coarse_point(lat, lng):
    """Round coordinates so only an approximate location is ever stored."""
    if lat is None or lng is None:
        return None
    d = settings.LOCATION_DECIMALS
    return Point(round(float(lng), d), round(float(lat), d), srid=4326)


class LatLngMixin(serializers.Serializer):
    lat = serializers.FloatField(required=False, allow_null=True, min_value=-90, max_value=90)
    lng = serializers.FloatField(required=False, allow_null=True, min_value=-180, max_value=180)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        if (attrs.get("lat") is None) != (attrs.get("lng") is None):
            raise serializers.ValidationError("lat and lng must be sent together.")
        return attrs


def point_to_dict(point):
    return {"lat": point.y, "lng": point.x} if point else None
