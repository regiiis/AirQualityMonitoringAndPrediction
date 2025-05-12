# Project-wide settings
project_prefix = "airq"
aws_region     = "eu-central-1"

# VPC configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24"]
availability_zones   = ["eu-central-1a"]

# Function names
data_ingestion_function_name = "air-quality-ingestion"
api_name                     = "air-quality-api"
bucket_name                  = "air-quality-readings"

# Lambda config
data_ingestion_zip_path = "../deployment/deployment_packages/data_ingestion.zip"

# Common tags
common_tags = {
  Project   = "AirQualityMonitoring"
  Owner     = "Regis"
  ManagedBy = "Terraform"
}

shared_tags = {
  ResourceType = "SharedInfrastructure"
}

data_ingestion_tags = {
  ResourceType = "DataIngestion"
}

ml_pipeline_tags = {
  ResourceType = "MLPipeline"
}
