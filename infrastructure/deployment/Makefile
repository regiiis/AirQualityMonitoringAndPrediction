.PHONY: deploy-all deploy-shared deploy-data-ingestion clean validate-all plan-all

# Variables
SHARED_DIR = ../terraform/shared/environments
DATA_INGESTION_DIR = ../terraform/data_ingestion/environments
LAMBDA_DIR = ../../lambda
ENV ?= dev

# Deploy all infrastructure (in correct order)
deploy-all: deploy-shared deploy-data-ingestion

# Deploy shared infrastructure only
deploy-shared:
    @echo "Deploying shared infrastructure to $(ENV) environment..."
    mkdir -p $(LAMBDA_DIR)
    cd $(SHARED_DIR)/$(ENV) && \
    terraform init && \
    terraform validate && \
    terraform apply -auto-approve
    @echo "✅ Shared infrastructure deployment complete!"

# Deploy data ingestion service only
deploy-data-ingestion:
    @echo "Deploying data ingestion service to $(ENV) environment..."
    mkdir -p $(LAMBDA_DIR)
    cd ../../app/handlers/data_ingestion && \
    zip -j $(LAMBDA_DIR)/data_ingestion.zip *.py requirements.txt

    # Check if Lambda function exists and handle import accordingly
    if aws lambda get-function --function-name $(ENV)-air-quality-ingestion >/dev/null 2>&1; then \
        echo "Function exists, importing into state..."; \
        cd $(DATA_INGESTION_DIR)/$(ENV) && \
        terraform init && \
        terraform import module.lambda.aws_lambda_function.data_ingestion $(ENV)-air-quality-ingestion || true; \
    else \
        echo "Function doesn't exist, creating new..."; \
    fi

    cd $(DATA_INGESTION_DIR)/$(ENV) && \
    terraform init && \
    terraform validate && \
    terraform apply -auto-approve
    @echo "✅ Data ingestion service deployment complete!"

# Validate all Terraform configurations
validate-all:
    @echo "Validating all Terraform configurations..."
    cd $(SHARED_DIR)/$(ENV) && terraform validate
    cd $(DATA_INGESTION_DIR)/$(ENV) && terraform validate
    @echo "✅ All configurations valid!"

# Plan all changes without applying
plan-all:
    @echo "Planning shared infrastructure changes..."
    cd $(SHARED_DIR)/$(ENV) && terraform plan

    @echo "Planning data ingestion service changes..."
    cd $(DATA_INGESTION_DIR)/$(ENV) && terraform plan

# Clean up deployment artifacts
clean:
    @echo "Cleaning up deployment artifacts..."
    rm -f $(LAMBDA_DIR)/*.zip
    find ../terraform -name "*.tfplan" -type f -delete
    find ../terraform -name ".terraform" -type d -exec rm -rf {} +
    @echo "✅ Cleanup complete!"

# Initialize all Terraform directories
init-all:
    @echo "Initializing all Terraform directories..."
    cd $(SHARED_DIR)/$(ENV) && terraform init
    cd $(DATA_INGESTION_DIR)/$(ENV) && terraform init
    @echo "✅ All directories initialized!"

# Display infrastructure endpoints and info
show-endpoints:
    @echo "🔍 Fetching infrastructure endpoints..."
    @echo "API Gateway URL:"
    @cd $(DATA_INGESTION_DIR)/$(ENV) && terraform output -raw api_gateway_url
    @echo "S3 Bucket Name:"
    @cd $(SHARED_DIR)/$(ENV) && terraform output -raw sensor_data_bucket

# Production deployment
deploy-all-prod: ENV=prod
deploy-all-prod: deploy-all
