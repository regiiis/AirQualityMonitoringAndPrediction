output "function_name" {
  description = "The name of the data_storer Lambda function"
  value       = aws_lambda_function.data_storer.function_name
}

output "function_arn" {
  description = "The ARN of the data_storer Lambda function"
  value       = aws_lambda_function.data_storer.arn
}

output "role_arn" {
  description = "The ARN of the data_storer Lambda role"
  value       = aws_iam_role.data_storer_role.arn
}
