# Read-only identity for scheduled drift detection in GitHub Actions.
# Exception: OIDC providers and IAM groups are blocked by AWS-managed SCPs.
# Pattern: key-only user (no identity policies) -> assumes drift-readonly role.
# See EXCEPTIONS.md#drift-ci

resource "aws_iam_user" "drift_ci" {
  #checkov:skip=CKV_AWS_273:SCP blocks OIDC providers; assume-only user is a documented exception (EXCEPTIONS.md#drift-ci)
  name = "drift-check-ci"
  path = "/ci/"
  tags = {
    Project     = "devsecops-lab"
    Environment = "ci"
    Owner       = "Harley305"
  }
}

# Trust only this exact user. Naming the user ARN (not the account root)
# means the user needs no sts:AssumeRole identity policy.
data "aws_iam_policy_document" "drift_trust" {
  statement {
    sid     = "AssumeFromDriftUser"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.drift_ci.arn]
    }
  }
}

resource "aws_iam_role" "drift_readonly" {
  name                 = "drift-readonly"
  path                 = "/ci/"
  assume_role_policy   = data.aws_iam_policy_document.drift_trust.json
  max_session_duration = 3600
  tags = {
    Project     = "devsecops-lab"
    Environment = "ci"
    Owner       = "Harley305"
  }
}

# Config/metadata reads only. Unlike ReadOnlyAccess, it can't read object data.
resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.drift_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

data "aws_iam_policy_document" "state_read" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "ReadStateObject"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/lab/terraform.tfstate"]
  }
}

resource "aws_iam_role_policy" "state_read" {
  name   = "drift-state-read"
  role   = aws_iam_role.drift_readonly.id
  policy = data.aws_iam_policy_document.state_read.json
}

# Terraform refresh needs Lambda reads that SecurityAudit omits (GetFunction
# returns a code-download URL). Scoped to this project's functions only.
data "aws_caller_identity" "drift" {}

data "aws_iam_policy_document" "drift_extra_reads" {
  statement {
    sid = "LambdaRefreshReads"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:ListVersionsByFunction",
    ]
    resources = ["arn:aws:lambda:us-east-2:${data.aws_caller_identity.drift.account_id}:function:devsecops-lab-*"]
  }

  # policy-check.sh: free IAM Access Analyzer policy validation. ValidatePolicy
  # only inspects the document it's given and has no resource-level permissions.
  statement {
    sid       = "AccessAnalyzerValidatePolicy"
    actions   = ["access-analyzer:ValidatePolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "drift_extra_reads" {
  name   = "drift-extra-reads"
  role   = aws_iam_role.drift_readonly.id
  policy = data.aws_iam_policy_document.drift_extra_reads.json
}
