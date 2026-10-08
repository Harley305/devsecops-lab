variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
}