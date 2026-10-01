variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "source_dir" {
  description = "Folder containing the Lambda code"
  type        = string
}

variable "bucket_name" {
  description = "Bucket the function writes records to"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of that bucket, used to scope permissions"
  type        = string
}

variable "log_retention_days" {
  description = "How long to keep function logs"
  type        = number
  default     = 14
}
