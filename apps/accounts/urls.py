from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    path("auth/otp/request/", views.OtpRequestView.as_view()),
    path("auth/otp/verify/", views.OtpVerifyView.as_view()),
    path("auth/token/refresh/", TokenRefreshView.as_view()),
    path("me/", views.MeView.as_view()),
    path("me/export/", views.ExportView.as_view()),
    path("me/device/", views.DeviceView.as_view()),
]
