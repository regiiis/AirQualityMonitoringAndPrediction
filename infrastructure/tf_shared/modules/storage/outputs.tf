output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.arn
}

output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.id
}

output "ssm_parameter_bucket_name" {
  description = "SSM parameter name for the readings bucket name"
  value       = aws_ssm_parameter.readings_bucket_name.name
}

output "ssm_parameter_bucket_arn" {
  description = "SSM parameter name for the readings bucket ARN"
  value       = aws_ssm_parameter.readings_bucket_arn.name
}
