# Zip the Python code. It's written inside .terraform/, which Git already ignores.
data "archive_file" "code" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.terraform/build/${var.name}-app.zip"
}

# Trust policy: only the Lambda service may use this role
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_cloudwatch_log_group" "app" {
  #checkov:skip=CKV_AWS_158:Logs use AWS-managed encryption by default; a customer-managed KMS key adds cost with no benefit for lab data
  name              = "/aws/lambda/${var.name}-app"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Permissions: write its own logs, write objects under records/ only, and send traces
data "aws_iam_policy_document" "app" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }

  statement {
    sid       = "WriteRecordsOnly"
    actions   = ["s3:PutObject"]
    resources = ["${var.bucket_arn}/records/*"]
  }

  # X-Ray does not support resource-level permissions, so "*" is required here
  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${var.name}-app"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_lambda_function" "app" {
  #checkov:skip=CKV_AWS_117:Function only calls S3 and CloudWatch; VPC placement would require a NAT Gateway or paid endpoints with no security gain
  #checkov:skip=CKV_AWS_116:No asynchronous trigger exists yet, so a dead-letter queue would never receive events; revisit when one is added
  #checkov:skip=CKV_AWS_173:Only environment variable is the non-secret bucket name, already encrypted at rest with an AWS-managed key
  #checkov:skip=CKV_AWS_272:Code signing requires AWS Signer setup; planned as a future supply-chain hardening upgrade
  #checkov:skip=CKV_AWS_115:New accounts often have an account concurrency limit of 10 and AWS requires 10 unreserved, so reserving concurrency would fail apply; revisit after a quota increase
  function_name    = "${var.name}-app"
  role             = aws_iam_role.app.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = 10
  memory_size      = 128
  tags             = var.tags

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.app, aws_iam_role_policy.app]
}
