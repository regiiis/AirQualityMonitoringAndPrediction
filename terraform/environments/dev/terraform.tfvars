aws_region              = "us-west-2"
environment             = "dev"
bucket_name             = "air-quality-readings-dev-bucket"
api_name                = "air-quality-api-dev"
data_validator_function_name = "air-quality-validator-dev"
data_validator_zip_path      = "../../../lambda/data_validator.zip"
data_storer_function_name   = "air-quality-storage-dev"
data_storer_zip_path        = "../../../lambda/data_storer.zip"

# VPC configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
