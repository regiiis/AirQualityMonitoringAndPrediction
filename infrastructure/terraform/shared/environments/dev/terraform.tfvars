environment = "dev"
aws_region = "eu-central-1"
project_prefix = "airq"
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

tags = {
  Project = "AirQualityMonitoring"
  Environment = "dev"
  ResourceType = "SharedInfrastructure"
  ManagedBy = "terraform"
}
