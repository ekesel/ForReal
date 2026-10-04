from django.conf import settings
from django.contrib.gis.db import models
from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.measure import D


class LocalityManager(models.Manager):
    def for_point(self, point):
        """Locality whose boundary contains the point, else the nearest centre within the fallback radius."""
        if point is None:
            return None
        hit = self.filter(boundary__intersects=point).first()
        if hit:
            return hit
        return (
            self.filter(centre__dwithin=(point, D(m=settings.LOCALITY_FALLBACK_RADIUS_M)))
            .annotate(dist=Distance("centre", point))
            .order_by("dist")
            .first()
        )


class Locality(models.Model):
    name = models.CharField(max_length=120)
    city = models.CharField(max_length=80)
    state = models.CharField(max_length=80, blank=True)
    centre = models.PointField(geography=True)
    boundary = models.MultiPolygonField(geography=True, null=True, blank=True)

    objects = LocalityManager()

    class Meta:
        verbose_name_plural = "localities"
        constraints = [models.UniqueConstraint(fields=["name", "city"], name="uniq_locality_city")]

    def __str__(self):
        return f"{self.name}, {self.city}"


class GeocodeCell(models.Model):
    """Remembers the reverse-geocoding answer for one coarse point, so each ~110 m cell
    is looked up at most once, including cells where the provider found nothing.
    Holds no reference to any user."""

    class Status(models.TextChoices):
        RESOLVED = "resolved"
        NO_RESULT = "no_result"

    # The coarse point itself, rounded to settings.LOCATION_DECIMALS.
    lat = models.DecimalField(max_digits=9, decimal_places=6)
    lng = models.DecimalField(max_digits=9, decimal_places=6)
    locality = models.ForeignKey(Locality, on_delete=models.SET_NULL, null=True, blank=True, related_name="cells")
    status = models.CharField(max_length=10, choices=Status.choices)
    # Which adapter answered, so cells can be re-resolved after switching adapters.
    provider = models.CharField(max_length=40)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["lat", "lng"], name="uniq_geocode_cell")]
        indexes = [models.Index(fields=["provider", "status"])]

    def __str__(self):
        return f"{self.lat}, {self.lng} ({self.status})"
