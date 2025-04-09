output "validator_function_name" {
  description = "The name of the validator Lambda function"
  value       = aws_lambda_function.validator.function_name
}

output "validator_function_arn" {
  description = "The ARN of the validator Lambda function"
  value       = aws_lambda_function.validator.arn
}

output "storage_function_name" {
  description = "The name of the storage Lambda function"
  value       = aws_lambda_function.storage.function_name
}

output "storage_function_arn" {
  description = "The ARN of the storage Lambda function"
  value       = aws_lambda_function.storage.arn
}
