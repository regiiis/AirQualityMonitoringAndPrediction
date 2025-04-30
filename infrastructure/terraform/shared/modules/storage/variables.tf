variable "bucket_name" {
  description = "Name of the S3 bucket for storing air quality readings"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "resource_prefix" {
  description = "Standardized prefix for all resources"
  type        = string
}
