output "function_name" {
  description = "The name of the data_validator Lambda function"
  value       = aws_lambda_function.data_validator.function_name
}

output "function_arn" {
  description = "The ARN of the data_validator Lambda function"
  value       = aws_lambda_function.data_validator.arn
}

output "role_arn" {
  description = "The ARN of the data_validator Lambda role"
  value       = aws_iam_role.data_validator_role.arn
}
