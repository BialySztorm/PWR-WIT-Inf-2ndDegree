from django.http import FileResponse, Http404
from rest_framework import generics
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Message, UploadedMedia
from .serializers import MessageSerializer, UploadedMediaSerializer

class HealthView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        return Response({"status": "ok"})

class MediaListView(generics.ListAPIView):
    queryset = UploadedMedia.objects.order_by("-uploaded_at")
    serializer_class = UploadedMediaSerializer

class MessageListCreateView(generics.ListCreateAPIView):
    queryset = Message.objects.order_by("-created_at")
    serializer_class = MessageSerializer

class MediaCreateView(generics.CreateAPIView):
    queryset = UploadedMedia.objects.all()
    serializer_class = UploadedMediaSerializer
    parser_classes = [MultiPartParser, FormParser]

class MediaListCreateView(generics.ListCreateAPIView):
    queryset = UploadedMedia.objects.order_by("-uploaded_at")
    serializer_class = UploadedMediaSerializer
    parser_classes = [MultiPartParser, FormParser]


class MediaDownloadView(APIView):
    def get(self, request, pk: int):
        try:
            media = UploadedMedia.objects.get(pk=pk)
        except UploadedMedia.DoesNotExist:
            raise Http404("File not found")

        # FileResponse streamuje plik
        return FileResponse(media.file.open("rb"), as_attachment=True)