from django.urls import path

from . import views

urlpatterns = [
    path("items/", views.ItemSearchView.as_view()),
    path("transactions/<uuid:pk>/suggestions/", views.SuggestionsView.as_view()),
    path("transactions/<uuid:pk>/items/", views.TransactionItemsView.as_view()),
    path("transactions/<uuid:pk>/items/confirm/", views.ConfirmItemsView.as_view()),
]
