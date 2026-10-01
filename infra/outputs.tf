output "gha_plan_role_arn" {
  description = "Role GitHub Actions assumes for terraform plan on pull requests"
  value       = module.github_oidc.plan_role_arn
}

output "gha_apply_role_arn" {
  description = "Role GitHub Actions assumes for terraform apply in the prod environment"
  value       = module.github_oidc.apply_role_arn
}

output "data_bucket_name" {
  value = module.storage.bucket_name
}

output "function_name" {
  value = module.app.function_name
}
