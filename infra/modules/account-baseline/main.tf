# Account-wide CIS AWS Foundations v5.0.0 settings. All free.
# These apply to the whole account (or the whole region), not just this lab's
# resources, so they live in their own module and are drift-checked like the rest.

# CIS 1.7, 1.8 (IAM.15, IAM.16). The account's SCP blocks IAM console passwords,
# so no user can have one today; the policy still applies if that ever changes.
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  password_reuse_prevention      = 24
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
}

# CIS 2.1.4 account level (S3.1). Backstops the per-bucket blocks: no bucket
# in this account can be made public, including ones created outside Terraform.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CIS 5.1.1 (EC2.7). Region-scoped: every new EBS volume in us-east-2 is
# encrypted with the AWS-managed aws/ebs key. No EBS volumes exist today.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# CIS 1.16 (IAM.18). A role for opening and managing AWS Support cases during
# an incident. Only principals in this account that are already allowed to
# call sts:AssumeRole on it can use it.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "support_trust" {
  statement {
    sid     = "AssumeFromThisAccount"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "support" {
  name                 = "${var.name}-support"
  description          = "Incident response: manage AWS Support cases (CIS 1.16)"
  assume_role_policy   = data.aws_iam_policy_document.support_trust.json
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "support" {
  role       = aws_iam_role.support.name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}
