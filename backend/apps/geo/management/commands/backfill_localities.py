from django.apps import apps
from django.core.management.base import BaseCommand

from apps.geo.models import GeocodeCell
from apps.geo.services import cell_key
from apps.geo.tasks import MODELS, assign_locality


class Command(BaseCommand):
    help = "Queue locality assignment for every transaction and merchant that has a location but no locality."

    def add_arguments(self, parser):
        parser.add_argument(
            "--regeocode-provider",
            metavar="PROVIDER",
            help="First forget the cells this provider could not name (status no_result), so they "
            "are looked up again under the current adapter. Resolved cells and localities are kept.",
        )

    def handle(self, *args, **options):
        provider = options["regeocode_provider"]
        if provider:
            deleted, _ = GeocodeCell.objects.filter(
                provider=provider, status=GeocodeCell.Status.NO_RESULT
            ).delete()
            self.stdout.write(f"Removed {deleted} no_result cells from provider '{provider}'.")

        rows = 0
        queue = {}  # coarse point -> one row that stands for it
        for label in MODELS:
            pending = apps.get_model(label).objects.filter(location__isnull=False, locality__isnull=True)
            for pk, location in pending.values_list("pk", "location").iterator():
                rows += 1
                queue.setdefault(cell_key(location), (label, str(pk)))
        # One task fills every row at the same coarse point, so each point is queued once.
        for label, pk in queue.values():
            assign_locality.delay(label, pk)
        self.stdout.write(f"{rows} rows without a locality; queued {len(queue)} tasks (one per coarse point).")
