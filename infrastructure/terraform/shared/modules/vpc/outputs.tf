#################################################
# VPC MODULE OUTPUTS
#################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "nat_gateway_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "ssm_parameter_vpc_id" {
  description = "Name of the SSM parameter containing VPC ID"
  value       = aws_ssm_parameter.vpc_id.name
}

output "ssm_parameter_private_subnet_ids" {
  description = "Name of the SSM parameter containing private subnet IDs"
  value       = aws_ssm_parameter.private_subnet_ids.name
}

output "ssm_parameter_lambda_sg_id" {
  description = "Name of the SSM parameter containing Lambda security group ID"
  value       = aws_ssm_parameter.lambda_security_group_id.name
}
