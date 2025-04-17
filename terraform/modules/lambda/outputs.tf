output "data_validator_function_name" {
  description = "The name of the data_validator Lambda function"
  value       = module.data_validator.function_name
}

output "data_validator_function_arn" {
  description = "The ARN of the data_validator Lambda function"
  value       = module.data_validator.function_arn
}

output "data_storer_function_name" {
  description = "The name of the data_storer Lambda function"
  value       = module.data_storer.function_name
}

output "data_storer_function_arn" {
  description = "The ARN of the data_storer Lambda function"
  value       = module.data_storer.function_arn
}
