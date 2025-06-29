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

variable "resource_prefix" {
  description = "Standardized prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

#################################################
# NETWORKING
#################################################
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

#################################################
# DATA CONSOLIDATION CONFIGURATION
#################################################
variable "source_bucket_name" {
  description = "S3 bucket containing source data files"
  type        = string
}

variable "consolidated_file_name" {
  description = "Name of the consolidated output file"
  type        = string
  default     = "consolidated_sensor_data.csv"
}

variable "source_prefix" {
  description = "S3 prefix for source data files"
  type        = string
  default     = "raw-data/"
}

#################################################
# ECS CONFIGURATION
#################################################
variable "task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "1024"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

#################################################
# SCHEDULING
#################################################
variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
  default     = "cron(0 2 */2 * ? *)"  # Every 2 days at 2 AM UTC
}

variable "schedule_timezone" {
  description = "Timezone for the schedule"
  type        = string
  default     = "UTC"
}

#################################################
# TAGS
#################################################
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
