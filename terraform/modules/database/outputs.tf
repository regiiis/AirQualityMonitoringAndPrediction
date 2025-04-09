output "bucket_name" {
  description = "The name of the S3 bucket for air quality readings"
  value       = aws_s3_bucket.readings_storage.bucket
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket for air quality readings"
  value       = aws_s3_bucket.readings_storage.arn
}
