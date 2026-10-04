from django.urls import path

from . import views

urlpatterns = [path("parser-templates/", views.ParserTemplateView.as_view())]
