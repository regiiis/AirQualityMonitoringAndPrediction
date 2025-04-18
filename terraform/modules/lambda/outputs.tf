output "data_ingestion_function_name" {
  description = "The name of the data_ingestion Lambda function"
  value       = module.data_ingestion.function_name
}

output "data_ingestion_function_arn" {
  description = "The ARN of the data_ingestion Lambda function"
  value       = module.data_ingestion.function_arn
}
