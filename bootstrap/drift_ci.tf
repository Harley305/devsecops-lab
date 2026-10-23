# Read-only identity for scheduled drift detection in GitHub Actions.
# Exception: OIDC blocked by AWS-managed SCP. See EXCEPTIONS.md#drift-ci

resource "aws_iam_group" "drift_readers" {
  name = "drift-readers"
  path = "/ci/"
}

resource "aws_iam_user" "drift_ci" {
  #checkov:skip=CKV_AWS_273:SCP blocks OIDC providers; read-only key is a documented exception (EXCEPTIONS.md#drift-ci)
  name = "drift-check-ci"
  path = "/ci/"
  tags = {
    Project     = "devsecops-lab"
    Environment = "ci"
    Owner       = "Harley305"
  }
}

resource "aws_iam_user_group_membership" "drift_ci" {
  user   = aws_iam_user.drift_ci.name
  groups = [aws_iam_group.drift_readers.name]
}

# Config/metadata reads only. Unlike ReadOnlyAccess, it can't read object data.
resource "aws_iam_group_policy_attachment" "security_audit" {
  group      = aws_iam_group.drift_readers.name
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

resource "aws_iam_group_policy" "state_read" {
  name   = "drift-state-read"
  group  = aws_iam_group.drift_readers.name
  policy = data.aws_iam_policy_document.state_read.json
}
