variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "github_repo" {
  description = "Repository allowed to assume these roles, as owner/repo"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
}