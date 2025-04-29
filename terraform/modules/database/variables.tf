variable "bucket_name" {
  description = "Name of the S3 bucket for storing air quality readings"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}
