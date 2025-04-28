variable "environment" {
  description = "The environment for the API Gateway (e.g., dev, staging, prod)"
  type        = string
}

variable "api_name" {
  description = "The name of the API Gateway"
  type        = string
}

variable "data_validator_lambda_invoke_arn" {
  description = "The ARN of the Lambda function to be invoked by the API Gateway"
  type        = string
}
