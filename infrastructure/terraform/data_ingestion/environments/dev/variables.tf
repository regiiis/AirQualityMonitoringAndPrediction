#################################################
# DATA INGESTION ENVIRONMENT VARIABLES
#################################################

#################################################
# GENERAL CONFIGURATION
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

variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state files"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
}

#################################################
# TAG CONFIGURATION
#################################################
# These replace the single "tags" variable
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

variable "data_ingestion_tags" {
  description = "Tags specific to data ingestion service"
  type        = map(string)
  default     = {}
}

#################################################
# LAMBDA CONFIGURATION
#################################################
variable "data_ingestion_function_name" {
  description = "Name of the data ingestion Lambda function"
  type        = string
}

variable "data_ingestion_zip_path" {
  description = "Path to the data ingestion Lambda deployment package"
  type        = string
}
