variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "enable_github_oidc" {
  description = "Create the GitHub OIDC provider and CI roles. Off by default: this account's organization policy blocks creating OIDC identity providers."
  type        = bool
  default     = false
}