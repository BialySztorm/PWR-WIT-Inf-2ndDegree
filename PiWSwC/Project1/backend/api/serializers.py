from rest_framework import serializers
from .models import Message, UploadedMedia
import os

class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ["id", "text", "created_at"]


class UploadedMediaSerializer(serializers.ModelSerializer):
    filename = serializers.SerializerMethodField()

    class Meta:
        model = UploadedMedia
        fields = ["id", "file", "filename", "uploaded_at"]

    def get_filename(self, obj):
        return os.path.basename(obj.file.name)