from django.urls import path

from . import views

urlpatterns = [
    path("consents/", views.ConsentView.as_view()),
    path("consents/history/", views.ConsentHistoryView.as_view()),
]
