output "readings_resource_id" {
  description = "The ID of the readings resource"
  value       = aws_api_gateway_resource.readings.id
}

output "post_readings_method_id" {
  description = "The ID of the POST method for readings"
  value       = aws_api_gateway_method.post_readings.id
}
