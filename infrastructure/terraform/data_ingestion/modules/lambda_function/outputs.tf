output "data_ingestion_function_name" {
  description = "The name of the data_ingestion Lambda function"
  value       = module.data_ingestion.function_name
}

output "data_ingestion_function_arn" {
  description = "The ARN of the data_ingestion Lambda function"
  value       = module.data_ingestion.function_arn
}

output "data_ingestion_function_invoke_arn" {
  description = "The invoke ARN for the Lambda function"
  value       = module.data_ingestion.function_invoke_arn
}

output "aws_s3_bucket" {
  description = "The S3 bucket resource for Lambda deployments"
  value       = aws_s3_bucket.lambda_deployments
}
