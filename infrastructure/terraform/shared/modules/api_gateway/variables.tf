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

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
