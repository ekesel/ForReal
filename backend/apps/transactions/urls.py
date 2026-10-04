from django.urls import path

from . import views

urlpatterns = [
    path("transactions/", views.TransactionListView.as_view()),
    path("transactions/batch/", views.IngestBatchView.as_view()),
    path("transactions/<uuid:pk>/", views.TransactionDetailView.as_view()),
    path("transactions/<uuid:pk>/location/", views.TransactionLocationView.as_view()),
]
