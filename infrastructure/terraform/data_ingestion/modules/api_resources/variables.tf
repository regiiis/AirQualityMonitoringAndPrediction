variable "api_id" {
  description = "ID of the shared API Gateway"
  type        = string
}

variable "data_ingestion_resource_id" {
  description = "ID of the data-ingestion resource in the shared API Gateway"
  type        = string
}

variable "data_validator_lambda_invoke_arn" {
  description = "ARN of the Lambda function for data validation"
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
