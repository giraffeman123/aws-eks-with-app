resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.name}-${var.mandatory_tags.Environment}-${data.aws_region.current.name}-codepipeline"

  tags = var.mandatory_tags
}

resource "aws_s3_bucket_versioning" "codepipeline_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}