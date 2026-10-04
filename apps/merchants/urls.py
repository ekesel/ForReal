from django.urls import path

from . import views

urlpatterns = [
    path("categories/", views.CategoryListView.as_view()),
    path("payees/pending/", views.PendingPayeesView.as_view()),
    path("payees/<int:pk>/suggestions/", views.PayeeSuggestionsView.as_view()),
    path("payees/<int:pk>/resolve/", views.ResolvePayeeView.as_view()),
    path("merchants/search/", views.MerchantSearchView.as_view()),
]
