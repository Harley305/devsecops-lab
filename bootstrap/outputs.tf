output "state_bucket_name" {
  description = "Pass this to: terraform init -backend-config=\"bucket=<name>\""
  value       = aws_s3_bucket.state.id
}
