variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "The environment for the Lambda function"
  type        = string
}

variable "function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "zip_s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
}

variable "zip_s3_key" {
  description = "S3 key for the Lambda deployment package"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket to store validated data"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Lambda VPC configuration"
  type        = string
}

variable "api_gateway_arn" {
  description = "ARN of the API Gateway for Lambda permission"
  type        = string
}

variable "signed_code_s3_bucket" {
  description = "S3 bucket to store signed Lambda code"
  type        = string
}

variable "signed_code_s3_prefix" {
  description = "Prefix for signed Lambda code in S3 bucket"
  type        = string
  default     = "signed/"
}

variable "zip_s3_version" {
  description = "S3 object version for Lambda ZIP file"
  type        = string
  default     = "LATEST"
}

variable "resource_prefix" {
  description = "Standardized prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the resources"
  type        = string
}
