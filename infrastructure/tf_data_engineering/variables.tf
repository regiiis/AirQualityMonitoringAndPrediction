#################################################
# DATA ENGINEERING ENVIRONMENT VARIABLES
#################################################

#################################################
# GENERAL CONFIGURATION - From common.tfvars
#################################################
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "project_prefix" {
  description = "Project prefix for all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

#################################################
# TAG CONFIGURATION - From common.tfvars
#################################################
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "environment_tags" {
  description = "Environment-specific tags"
  type        = map(string)
  default     = {}
}

variable "data_engineering_tags" {
  description = "Tags specific to data engineering service"
  type        = map(string)
  default     = {}
}

#################################################
# DATA CONSOLIDATION CONFIGURATION
#################################################
variable "consolidated_file_name" {
  description = "Name of the consolidated output file"
  type        = string
}

variable "consolidated_path" {
  description = "Path of the consolidated output file"
  type        = string
}

variable "sensor_data_path" {
  description = "S3 prefix for source data files"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for ECS task"
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

variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
  default     = "cron(0 2 */2 * ? *)"
}
