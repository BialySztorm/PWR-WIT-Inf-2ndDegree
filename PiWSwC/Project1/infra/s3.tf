resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "media_bucket" {
  bucket        = "chatapp-media-bucket-${random_id.bucket_id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "media_bucket_public_access" {
  bucket                  = aws_s3_bucket.media_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "media_bucket_policy" {
  bucket = aws_s3_bucket.media_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_bucket.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.media_bucket_public_access]
}

resource "aws_s3_object" "frontend_zip" {
  bucket = aws_s3_bucket.media_bucket.id
  key    = "frontend-src.zip"
  source = "${path.module}/../deploy/frontend-src.zip"
  content_type = "application/zip"
  etag   = filemd5("${path.module}/../deploy/frontend-src.zip")
}

resource "aws_s3_object" "backend_zip" {
  bucket = aws_s3_bucket.media_bucket.id
  key    = "backend-src.zip"
  source = "${path.module}/../deploy/backend-src.zip"
  content_type = "application/zip"
  etag   = filemd5("${path.module}/../deploy/backend-src.zip")
}

