variable "function_name" {
  description = "The name of the data_storer Lambda function"
  type        = string
}

variable "zip_path" {
  description = "The path to the ZIP file for the data_storer Lambda function"
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket for storing validated data"
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
  description = "The ARN of the API Gateway execution role"
  type        = string
}
