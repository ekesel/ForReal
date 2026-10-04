import logging

from django.apps import AppConfig

log = logging.getLogger("forreal.startup")


class AccountsConfig(AppConfig):
    name = "apps.accounts"

    def ready(self):
        from django.conf import settings

        from config.startup import check_sender_class, closed_testing_warning

        check_sender_class(
            debug=settings.DEBUG, tester_phones=settings.TESTER_PHONES, otp_sender=settings.OTP_SENDER
        )

        # Said loudly in every process that starts, so it cannot be left on unnoticed.
        warning = closed_testing_warning(settings.TESTER_PHONES)
        if warning:
            log.warning(warning)
