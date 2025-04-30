# Environment
environment = "prod"

# Environment-specific tags
environment_tags = {
  Environment = "Prod"
}

# Production environment might use different subnet CIDRs
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
public_subnet_cidrs = ["10.0.110.0/24", "10.0.120.0/24"]
availability_zones = ["eu-central-1a", "eu-central-1b"]
