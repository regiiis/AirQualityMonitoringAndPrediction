#################################################
# DEV ENVIRONMENT VARIABLES
#################################################
# This file defines all variables used in the dev environment
# These variables configure the modules for development settings

#################################################
# GENERAL CONFIGURATION
#################################################
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"
}

#################################################
# STORAGE CONFIGURATION
#################################################
variable "bucket_name" {
  description = "Name of the S3 bucket for storing air quality readings"
  type        = string
  default     = "sensor_data"
}

#################################################
# API CONFIGURATION
#################################################
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

#################################################
# LAMBDA CONFIGURATION
#################################################
variable "validator_function_name" {
  description = "Name of the validator Lambda function"
  type        = string
}

variable "validator_zip_path" {
  description = "Path to the validator Lambda deployment package"
  type        = string
}

variable "storage_function_name" {
  description = "Name of the storage Lambda function"
  type        = string
}

variable "storage_zip_path" {
  description = "Path to the storage Lambda deployment package"
  type        = string
}

#################################################
# VPC CONFIGURATION
#################################################
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}
