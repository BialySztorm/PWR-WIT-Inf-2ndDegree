from django.urls import path
from .views import HealthView, MessageListCreateView, MediaListCreateView, MediaDownloadView, MediaListView, MeView

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("api/messages/", MessageListCreateView.as_view(), name="messages"),
    path("api/media/", MediaListCreateView.as_view(), name="media-list-create"),
    path("api/media/list/", MediaListView.as_view(), name="media-list"),
    path("api/media/<int:pk>/", MediaDownloadView.as_view(), name="media-download"),
    path("api/me/", MeView.as_view(), name="me"),
]