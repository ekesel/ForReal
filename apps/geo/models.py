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
