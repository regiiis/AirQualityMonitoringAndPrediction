output "function_name" {
  description = "The name of the data_ingestion Lambda function"
  value       = aws_lambda_function.data_ingestion.function_name
}

output "function_arn" {
  description = "The ARN of the data_ingestion Lambda function"
  value       = aws_lambda_function.data_ingestion.arn
}

output "role_arn" {
  description = "The ARN of the data_ingestion Lambda role"
  value       = aws_iam_role.data_ingestion_role.arn
}

output "function_invoke_arn" {
  description = "The invoke ARN of the data_ingestion Lambda function"
  value       = aws_lambda_function.data_ingestion.invoke_arn
}
