#################################################
# SHARED INFRASTRUCTURE VARIABLES
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

#################################################
# TAG CONFIGURATION
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

variable "shared_tags" {
  description = "Tags for shared infrastructure resources"
  type        = map(string)
  default     = {}
}

variable "data_ingestion_tags" {
  description = "Tags for data ingestion resources"
  type        = map(string)
  default     = {}
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

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

#################################################
# API CONFIGURATION
#################################################
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

#################################################
# STORAGE CONFIGURATION
#################################################
variable "bucket_name" {
  description = "Name of the S3 bucket for storing air quality readings"
  type        = string
}
