#################################################
# DATA INGESTION OUTPUTS
#################################################

# Lambda function outputs
output "data_ingestion_function_name" {
  description = "The name of the data ingestion Lambda function"
  value       = module.lambda.data_ingestion_function_name
}

output "data_ingestion_function_arn" {
  description = "The ARN of the data ingestion Lambda function"
  value       = module.lambda.data_ingestion_function_arn
}

# API endpoint outputs (from SSM parameters)
output "api_gateway_url" {
  description = "The URL for the API Gateway"
  value       = "${data.aws_ssm_parameter.api_invoke_url.value}/data-ingestion/readings"
  sensitive = true
}

# Reference to shared resources
output "shared_vpc_id" {
  description = "The VPC ID from shared infrastructure"
  value       = data.aws_ssm_parameter.vpc_id.value
  sensitive = true
}

output "shared_bucket_name" {
  description = "The name of the shared sensor data bucket"
  value       = data.aws_ssm_parameter.readings_bucket_name.value
  sensitive = true
}

# CloudFormation stack output
output "cloudformation_stack_id" {
  description = "The ID of the CloudFormation stack"
  value       = aws_cloudformation_stack.data_ingestion_service.id
}
