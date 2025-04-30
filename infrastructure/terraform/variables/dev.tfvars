# Environment
environment = "dev"

# Environment-specific tags
environment_tags = {
  Environment = "Dev"
}

# VPC configuration
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
availability_zones = ["eu-central-1a", "eu-central-1b"]
