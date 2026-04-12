from rest_framework import serializers
from .models import Message, UploadedMedia, UserProfile
import os

def _display_name_for_sub(sub: str | None):
    if not sub:
        return None
    p = UserProfile.objects.filter(sub=sub).first()
    if p and p.friendly_name.strip():
        return p.friendly_name.strip()
    return sub  # fallback

class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ["id", "text", "created_at", "sender"]
        read_only_fields = ["id", "created_at", "sender"]

    def get_sender(self, obj: Message):
        return _display_name_for_sub(getattr(obj, "sender_sub", None))

class UploadedMediaSerializer(serializers.ModelSerializer):
    filename = serializers.SerializerMethodField()
    sender = serializers.SerializerMethodField()

    class Meta:
        model = UploadedMedia
        fields = ["id", "file", "filename", "uploaded_at", "sender"]
        read_only_fields = ["id", "filename", "uploaded_at", "sender"]

    def get_filename(self, obj):
        return os.path.basename(obj.file.name)

    def get_sender(self, obj: UploadedMedia):
        return _display_name_for_sub(getattr(obj, "sender_sub", None))

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ["friendly_name"]