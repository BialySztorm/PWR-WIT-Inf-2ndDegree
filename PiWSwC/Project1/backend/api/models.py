from django.db import models

class Message(models.Model):
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    sender_sub = models.CharField(max_length=64, null=True, blank=True, db_index=True)

    def __str__(self) -> str:
        return f"{self.id}: {self.text[:30]}"


class UploadedMedia(models.Model):
    file = models.FileField(upload_to="uploads/")
    uploaded_at = models.DateTimeField(auto_now_add=True)
    sender_sub = models.CharField(max_length=64, null=True, blank=True, db_index=True)

    def __str__(self) -> str:
        return f"{self.id}: {self.file.name}"

class UserProfile(models.Model):
    # Cognito subject (stable user id)
    sub = models.CharField(max_length=64, unique=True)
    friendly_name = models.CharField(max_length=64, blank=True, default="")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)