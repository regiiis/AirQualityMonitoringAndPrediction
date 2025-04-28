#################################################
# DEV ENVIRONMENT VARIABLES
#################################################
# This file defines all variables used in the dev environment
# These variables configure the modules for development settings

#################################################
# GENERAL CONFIGURATION
#################################################
# Defined in tfvars file
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

# Defined in tfvars file
variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

# Defined in tfvars file
variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}

#################################################
# STORAGE CONFIGURATION
#################################################
# Defined in tfvars file
variable "bucket_name" {
  description = "Name of the S3 bucket for storing air quality readings"
  type        = string
}

#################################################
# API CONFIGURATION
#################################################
# Defined in tfvars file
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

#################################################
# LAMBDA CONFIGURATION
#################################################
# Defined in tfvars file
variable "data_ingestion_function_name" {
  description = "Name of the data ingestion Lambda function"
  type        = string
  default     = "data_ingestion_function"
}

# Defined in tfvars file
variable "data_ingestion_zip_path" {
  description = "Path to the data ingestion Lambda deployment package"
  type        = string
}


#################################################
# VPC CONFIGURATION
#################################################
# Defined in tfvars file
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# Defined in tfvars file
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Defined in tfvars file
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}
