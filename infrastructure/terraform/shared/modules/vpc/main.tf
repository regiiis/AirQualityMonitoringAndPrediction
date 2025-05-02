#################################################
# SHARED VPC MODULE
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.resource_prefix}-vpc"
    },
    var.tags
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.resource_prefix}-igw"
    },
    var.tags
  )
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(
    {
      Name = "${var.resource_prefix}-private-subnet-${count.index + 1}"
    },
    var.tags
  )
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.resource_prefix}-private-route-table"
    },
    var.tags
  )
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create security group for Lambda functions
resource "aws_security_group" "lambda_sg" {
  name        = "${var.resource_prefix}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS to S3 VPC endpoint
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "Allow HTTPS access to S3 via VPC endpoint"
  }

  # Allow HTTPS to CloudWatch Logs VPC endpoint
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private[*].cidr_block # Allow to all private subnet CIDRs
    description = "Allow HTTPS access to CloudWatch Logs via VPC endpoint"
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-lambda-sg"
    },
    var.tags
  )
}

# Add a CloudWatch Logs VPC endpoint to allow Lambda to log directly
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(
    {
      Name = "${var.resource_prefix}-logs-endpoint"
    },
    var.tags
  )
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.resource_prefix}-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Allow HTTPS access from Lambda"
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-vpc-endpoint-sg"
    },
    var.tags
  )
}

# Create VPC Endpoints for Lambda, S3, and other AWS services
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(
    {
      Name = "${var.resource_prefix}-s3-endpoint"
    },
    var.tags
  )
}

# Export parameters to SSM for CloudFormation stacks
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/shared/${var.environment}/vpc/id"
  type  = "String"
  value = aws_vpc.main.id
  tags  = var.tags
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/shared/${var.environment}/vpc/private-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
  tags  = var.tags
}

resource "aws_ssm_parameter" "lambda_security_group_id" {
  name  = "/shared/${var.environment}/vpc/lambda-sg-id"
  type  = "String"
  value = aws_security_group.lambda_sg.id
  tags  = var.tags
}
