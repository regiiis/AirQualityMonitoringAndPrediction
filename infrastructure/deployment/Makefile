.PHONY: deploy-all deploy-shared deploy-data-ingestion clean validate-all plan-all

# Variables
SHARED_DIR = ../terraform/shared/environments
DATA_INGESTION_DIR = ../terraform/data_ingestion/environments
VARIABLES_DIR = ../terraform/variables
ENV ?= dev

# Deploy all infrastructure (in correct order)
deploy-all: deploy-shared deploy-data-ingestion

# Deploy shared infrastructure only
deploy-shared:
	@echo "Deploying shared infrastructure to $(ENV) environment..."
	cd $(SHARED_DIR)/$(ENV) && \
	terraform init && \
	terraform validate && \
	terraform apply -auto-approve \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars
	@echo "✅ Shared infrastructure deployment complete!"

# Deploy data ingestion service only
deploy-data-ingestion:
    @echo "Deploying data ingestion service to $(ENV) environment..."
    @echo "Packaging Lambda code..."
    mkdir -p ../../lambda/package
    pip install -r ../../app/handlers/data_ingestion/requirements.txt -t ../../lambda/package
    cp ../../app/handlers/data_ingestion/*.py ../../lambda/package/
    cd ../../lambda/package && zip -r ../data_ingestion.zip .
    rm -rf ../../lambda/package

    cd $(DATA_INGESTION_DIR)/$(ENV) && \
    terraform init && \
    terraform validate && \
    terraform apply -auto-approve \
        -var-file=$(VARIABLES_DIR)/common.tfvars \
        -var-file=$(VARIABLES_DIR)/$(ENV).tfvars
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
	rm -f ../../lambda/*.zip
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
