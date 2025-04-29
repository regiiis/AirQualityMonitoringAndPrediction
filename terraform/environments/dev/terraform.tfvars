aws_region                   = "eu-central-2"
environment                  = "dev"
bucket_name                  = "air-quality-readings-bucket"
api_name                     = "air-quality-api"
data_ingestion_function_name = "air-quality-ingestion"
data_ingestion_zip_path      = "../../../lambda/data_ingestion.zip"

tags = {
  Owner   = "Regis"
  Project = "AirQualityMonitoring"
  Environment = "dev"
}

# VPC configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
