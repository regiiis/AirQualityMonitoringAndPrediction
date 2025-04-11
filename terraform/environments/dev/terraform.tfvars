aws_region              = "us-west-2"
environment             = "dev"
bucket_name             = "air-quality-readings-dev-bucket"
api_name                = "air-quality-api-dev"
validator_function_name = "air-quality-validator-dev"
validator_zip_path      = "../../../lambda/validator.zip"
storage_function_name   = "air-quality-storage-dev"
storage_zip_path        = "../../../lambda/storage.zip"

# VPC configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
