output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.arn
}

# Add this missing output referenced in dev/outputs.tf
output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.readings_storage.id
}
