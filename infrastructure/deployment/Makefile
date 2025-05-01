.PHONY: deploy-all deploy-shared deploy-data-ingestion clean validate-all plan-all package-lambda debug_zip_path check-aws-credentials upload-lambda-zip

# Variables
SHARED_DIR = infrastructure/terraform/shared/environments
DATA_INGESTION_DIR = infrastructure/terraform/data_ingestion/environments
VARIABLES_DIR = infrastructure/terraform/variables
PACKAGE_DIR = infrastructure/deployment/deployment_packages
ENV ?= dev

# Check if AWS credentials are valid
check-aws-credentials:
	@echo "🔑 Checking AWS credentials..."
	@if ! aws sts get-caller-identity > /dev/null 2>&1; then \
		echo "❌ AWS credentials are invalid or expired. Please refresh your credentials."; \
		echo "   Run 'aws configure' or set the appropriate environment variables."; \
		exit 1; \
	fi
	@echo "✅ AWS credentials are valid"

# Deploy all infrastructure (in correct order)
deploy-all: check-aws-credentials deploy-shared deploy-data-ingestion

# Deploy shared infrastructure only
deploy-shared: check-aws-credentials
	@echo "Deploying shared infrastructure to $(ENV) environment..."
	terraform -chdir=$(SHARED_DIR)/$(ENV) init
	terraform -chdir=$(SHARED_DIR)/$(ENV) validate
	terraform -chdir=$(SHARED_DIR)/$(ENV) apply -auto-approve \
		-var-file=../../../variables/common.tfvars \
		-var-file=../../../variables/$(ENV).tfvars
	@echo "✅ Shared infrastructure deployment complete!"

# Package the Lambda function into a zip
package-lambda:
	@echo "📦 Packaging Lambda code..."
	mkdir -p $(PACKAGE_DIR)/temp_dir
	pip install -r app/handlers/data_ingestion/requirements.txt -t $(PACKAGE_DIR)/temp_dir
	cp app/handlers/data_ingestion/*.py $(PACKAGE_DIR)/temp_dir/
	cd $(PACKAGE_DIR)/temp_dir && zip -r ../data_ingestion.zip .
	@echo "🧹 Cleaning up temp_dir..."
	rm -rf $(PACKAGE_DIR)/temp_dir/*
	@if [ ! -f $(PACKAGE_DIR)/data_ingestion.zip ]; then \
		echo "❌ Error: Lambda package was not created successfully"; \
		exit 1; \
	fi
	@echo "✅ Lambda package created: $(PACKAGE_DIR)/data_ingestion.zip"

# Add this new target to debug path issues
debug_zip_path:
	@echo "=== PATH DEBUGGING INFO ==="
	@echo "Current directory: $$(pwd)"
	@echo "Checking file existence from current directory:"
	@ls -la $(PACKAGE_DIR)/data_ingestion.zip || echo "❌ File not found at $(PACKAGE_DIR)/data_ingestion.zip"
	@echo "Checking from terraform directory:"
	@cd $(DATA_INGESTION_DIR)/$(ENV) && echo "Now in: $$(pwd)"
	@cd $(DATA_INGESTION_DIR)/$(ENV) && ls -la ../../../../deployment/deployment_packages/data_ingestion.zip || echo "❌ File not found when checked from Terraform directory"
	@echo "Creating test path used by Terraform:"
	@cd $(DATA_INGESTION_DIR)/$(ENV) && echo "Current dir: $$(pwd)"
	@cd $(DATA_INGESTION_DIR)/$(ENV) && echo "The path '../../../../deployment/deployment_packages/data_ingestion.zip' resolves to: $$(realpath '../../../../deployment/deployment_packages/data_ingestion.zip' 2>/dev/null || echo 'Invalid path')"
	@echo "Absolute path calculation:"
	@echo "Calculated absolute path: $$(readlink -f $(PACKAGE_DIR)/data_ingestion.zip)"
	@ls -la "$$(readlink -f $(PACKAGE_DIR)/data_ingestion.zip)" || echo "❌ File not found at absolute path"

# Deploy data ingestion service only
deploy-data-ingestion: check-aws-credentials package-lambda
	@echo "Deploying data ingestion service to $(ENV) environment..."
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) init
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) validate
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) apply -auto-approve \
		-var-file=../../../variables/common.tfvars \
		-var-file=../../../variables/$(ENV).tfvars

# Upload Lambda zip to S3 (only the S3 object resource)
upload-lambda-zip: check-aws-credentials package-lambda
	@echo "Uploading Lambda zip to S3..."
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) init
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) validate
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) apply -target=aws_s3_object.data_ingestion_zip \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars

# Validate all Terraform configurations
validate-all:
	@echo "Validating all Terraform configurations..."
	terraform -chdir=$(SHARED_DIR)/$(ENV) validate
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) validate
	@echo "✅ All configurations valid!"

# Plan all changes without applying
plan-all:
	@echo "Planning shared infrastructure changes..."
	terraform -chdir=$(SHARED_DIR)/$(ENV) plan \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars
	@echo "Planning data ingestion service changes..."
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) plan \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars

# Clean up deployment artifacts
clean:
	@echo "Cleaning up deployment artifacts..."
	rm -rf $(PACKAGE_DIR)
	find infrastructure/terraform -name "*.tfplan" -type f -delete
	find infrastructure/terraform -name ".terraform" -type d -exec rm -rf {} +
	@echo "✅ Cleanup complete!"

# Initialize all Terraform directories
init-all:
	@echo "Initializing all Terraform directories..."
	terraform -chdir=$(SHARED_DIR)/$(ENV) init
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) init
	@echo "✅ All directories initialized!"

# Display infrastructure endpoints and info
show-endpoints:
	@echo "🔍 Fetching infrastructure endpoints..."
	@echo "API Gateway URL:"
	terraform -chdir=$(DATA_INGESTION_DIR)/$(ENV) output -raw api_gateway_url
	@echo "S3 Bucket Name:"
	terraform -chdir=$(SHARED_DIR)/$(ENV) output -raw sensor_data_bucket
