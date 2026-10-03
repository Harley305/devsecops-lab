resource "aws_s3_bucket" "data" {
  #checkov:skip=CKV2_AWS_62:No service consumes bucket events yet; revisit when a trigger is added
  #checkov:skip=CKV_AWS_18:Access logs would need a separate log bucket that fails the same check; CloudTrail data events planned once deployed
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles cost; lab data is versioned and non-critical
  #checkov:skip=CKV_AWS_145:Encrypted at rest with AWS-managed AES256 keys; a customer-managed KMS key adds monthly cost with no benefit for lab data
  bucket_prefix = "${var.name}-data-"
  force_destroy = true # lab only: lets destroy remove a non-empty bucket
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Expire old object versions after 90 days and clean up failed uploads
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
