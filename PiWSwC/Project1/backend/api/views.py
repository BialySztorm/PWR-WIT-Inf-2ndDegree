from django.http import FileResponse, Http404
from rest_framework import generics
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied
from rest_framework.permissions import AllowAny
import jwt

from .models import Message, UploadedMedia, UserProfile
from .serializers import MessageSerializer, UploadedMediaSerializer, UserProfileSerializer
from .cognito_auth import get_sender_from_request, get_payload_from_request

class HealthView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        return Response({"status": "ok"})

class MediaListView(generics.ListAPIView):
    queryset = UploadedMedia.objects.order_by("-uploaded_at")
    serializer_class = UploadedMediaSerializer
    permission_classes = [AllowAny]

class MessageListCreateView(generics.ListCreateAPIView):
    queryset = Message.objects.order_by("-created_at")
    serializer_class = MessageSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        payload = get_payload_from_request(self.request)
        if payload:
            sub = payload.get("sub")
            if sub:
                UserProfile.objects.get_or_create(sub=sub)
                serializer.save(sender_sub=sub)
                return

        serializer.save(sender_sub=None)

class MediaListCreateView(generics.ListCreateAPIView):
    queryset = UploadedMedia.objects.order_by("-uploaded_at")
    serializer_class = UploadedMediaSerializer
    parser_classes = [MultiPartParser, FormParser]
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        payload = get_payload_from_request(self.request)
        if payload:
            sub = payload.get("sub")
            if sub:
                UserProfile.objects.get_or_create(sub=sub)
                serializer.save(sender_sub=sub)
                return

        serializer.save(sender_sub=None)


class MediaDownloadView(APIView):
    def get(self, request, pk: int):
        try:
            media = UploadedMedia.objects.get(pk=pk)
        except UploadedMedia.DoesNotExist:
            raise Http404("File not found")

        # FileResponse streamuje plik
        return FileResponse(media.file.open("rb"), as_attachment=True)

class MeView(APIView):
    def get(self, request):
        payload = get_payload_from_request(request)

        if not payload:
            return Response({"friendly_name": "Guest", "is_authenticated": False}, status=200)

        sub = payload.get("sub")
        profile, _ = UserProfile.objects.get_or_create(sub=sub)
        return Response(UserProfileSerializer(profile).data)

    def put(self, request):
        try:
            payload = get_payload_from_request(request)
        except (jwt.InvalidTokenError, jwt.PyJWTError, RuntimeError) as e:
            raise AuthenticationFailed(str(e))

        if not payload:
            raise AuthenticationFailed("Missing Bearer token")

        sub = payload.get("sub")
        if not sub:
            raise AuthenticationFailed("Token missing sub")

        profile, _ = UserProfile.objects.get_or_create(sub=sub)
        ser = UserProfileSerializer(profile, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)

        name = (ser.validated_data.get("friendly_name") or "").strip()
        profile.friendly_name = name
        profile.save()

        return Response(UserProfileSerializer(profile).data)