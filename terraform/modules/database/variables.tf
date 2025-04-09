variable "bucket_name" {
    description = "The name of the S3 bucket for storing air quality readings"
    type        = string
}

variable "environment" {
    description = "The environment for the deployment (e.g., dev, prod)"
    type        = string
}
