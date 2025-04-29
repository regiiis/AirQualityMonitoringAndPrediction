variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_key_name" {
  description = "Name of the API key for device authentication"
  type        = string
}

variable "usage_plan_name" {
  description = "Name of the API usage plan"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group for API Gateway logs"
  type        = string
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "data_validator_lambda_invoke_arn" {
  description = "ARN of the Lambda function for data validation"
  type        = string
}
