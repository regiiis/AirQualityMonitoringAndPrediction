#################################################
# SHARED INFRASTRUCTURE OUTPUTS
#################################################

# VPC outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "lambda_security_group_id" {
  description = "The ID of the Lambda security group"
  value       = module.vpc.lambda_security_group_id
}

# Storage outputs
output "sensor_data_bucket" {
  description = "The name of the S3 bucket for sensor data"
  value       = module.storage.bucket_name
}

output "sensor_data_bucket_arn" {
  description = "The ARN of the S3 bucket for sensor data"
  value       = module.storage.bucket_arn
}

# API Gateway outputs
output "api_id" {
  description = "The ID of the API Gateway"
  value       = module.api_gateway.api_id
}

output "api_execution_arn" {
  description = "The execution ARN of the API Gateway"
  value       = module.api_gateway.api_execution_arn
}

output "api_invoke_url" {
  description = "The invoke URL of the API Gateway"
  value       = module.api_gateway.api_invoke_url
}

output "api_stage_name" {
  description = "The name of the API Gateway stage"
  value       = module.api_gateway.stage_name
}

# API Key output (sensitive)
output "api_key" {
  description = "The API key for device authentication"
  value       = module.api_gateway.api_key
  sensitive   = true
}

output "data_ingestion_resource_id" {
  description = "The ID of the data ingestion resource in the API Gateway"
  value       = module.api_gateway.data_ingestion_resource_id
}

# SSM Parameter outputs for CloudFormation integration
output "ssm_vpc_id_param" {
  description = "The SSM parameter name for VPC ID"
  value       = "/shared/${var.environment}/vpc/id"
}

output "ssm_private_subnet_ids_param" {
  description = "The SSM parameter name for private subnet IDs"
  value       = "/shared/${var.environment}/vpc/private-subnet-ids"
}

output "ssm_lambda_security_group_id_param" {
  description = "The SSM parameter name for Lambda security group ID"
  value       = "/shared/${var.environment}/vpc/lambda-sg-id"
}

output "ssm_readings_bucket_name_param" {
  description = "The SSM parameter name for readings bucket name"
  value       = "/shared/${var.environment}/storage/readings-bucket-name"
}

# CloudFormation Stack outputs
output "cloudformation_stack_id" {
  description = "The ID of the CloudFormation stack"
  value       = aws_cloudformation_stack.shared_infrastructure.id
}

output "cloudformation_stack_outputs" {
  description = "The outputs of the CloudFormation stack"
  value       = aws_cloudformation_stack.shared_infrastructure.outputs
}
