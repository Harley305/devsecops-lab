# Creates the S3 bucket that stores Terraform state for infra/.
# Applied once, by hand, with local state. Never managed by CI.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  tags = {
    Project     = "devsecops-lab"
    Owner       = "chris"
    Environment = "lab"
    ManagedBy   = "terraform-bootstrap"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV2_AWS_62:No service consumes state bucket events
  #checkov:skip=CKV_AWS_18:Access logs would need a separate log bucket that fails the same check; CloudTrail data events planned once deployed
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles cost; state is versioned and protected by prevent_destroy
  #checkov:skip=CKV_AWS_145:Encrypted at rest with AWS-managed AES256 keys; a customer-managed KMS key adds monthly cost with no benefit for lab state
  bucket_prefix = "devsecops-lab-tfstate-"
  tags          = local.tags

  # Losing state means Terraform forgets everything it built
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Every state change keeps the previous version, so a bad apply can be rolled back
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Keep old state versions 90 days, then clean up, so storage stays near zero
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
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

# Refuse any request that isn't encrypted in transit (HTTPS only)
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
