#################################################
# SHARED VPC MODULE
#################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current AWS region
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.environment}-vpc"
    },
    var.tags
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.environment}-igw"
    },
    var.tags
  )
}

# Create public subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
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
      Name = "${var.environment}-private-subnet-${count.index + 1}"
    },
    var.tags
  )
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    {
      Name = "${var.environment}-nat-eip"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.igw]
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    {
      Name = "${var.environment}-nat-gateway"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.igw]
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    {
      Name = "${var.environment}-public-route-table"
    },
    var.tags
  )
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(
    {
      Name = "${var.environment}-private-route-table"
    },
    var.tags
  )
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create security group for Lambda functions
resource "aws_security_group" "lambda_sg" {
  name        = "${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.environment}-lambda-sg"
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
      Name = "${var.environment}-s3-endpoint"
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

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/shared/${var.environment}/vpc/public-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)
  tags  = var.tags
}

resource "aws_ssm_parameter" "lambda_security_group_id" {
  name  = "/shared/${var.environment}/vpc/lambda-sg-id"
  type  = "String"
  value = aws_security_group.lambda_sg.id
  tags  = var.tags
}
