output "state_bucket_name" {
  description = "Pass this to: terraform init -backend-config=\"bucket=<name>\""
  value       = aws_s3_bucket.state.id
}

output "drift_role_arn" {
  description = "Role assumed by the drift-check workflow (stored as GitHub secret DRIFT_ROLE_ARN)"
  value       = aws_iam_role.drift_readonly.arn
}
