variable "validator_function_name" {
  description = "The name of the validator Lambda function"
  type        = string
}

variable "validator_zip_path" {
  description = "The path to the ZIP file for the validator Lambda function"
  type        = string
}

variable "storage_function_name" {
  description = "The name of the storage Lambda function"
  type        = string
}

variable "storage_zip_path" {
  description = "The path to the ZIP file for the storage Lambda function"
  type        = string
}

variable "storage_bucket_name" {
  description = "The name of the S3 bucket for storing validated data"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "The ARN of the API Gateway execution role"
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
