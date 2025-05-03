.PHONY: deploy-all deploy-shared deploy-data-ingestion clean validate-all plan-all package-lambda check-aws-credentials destroy-all

# Variables
SHARED_DIR = infrastructure/terraform/shared
DATA_INGESTION_DIR = infrastructure/terraform/data_ingestion
VARIABLES_DIR = infrastructure/terraform/variables
PACKAGE_DIR = infrastructure/deployment/deployment_packages

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
	terraform -chdir=$(SHARED_DIR) init -reconfigure\
	  -backend-config="key=$(ENV)/shared/terraform.tfstate"
	terraform -chdir=$(SHARED_DIR) validate
	terraform -chdir=$(SHARED_DIR) apply -auto-approve \
		-var-file=./../variables/common.tfvars \
		-var-file=./../variables/$(ENV).tfvars
	@echo "✅ Shared infrastructure deployment complete!"

# Deploy data ingestion service only
deploy-data-ingestion: check-aws-credentials package-lambda
	@echo "Deploying data ingestion service to $(ENV) environment..."
	terraform -chdir=$(DATA_INGESTION_DIR) init -reconfigure\
	  -backend-config="key=$(ENV)/data_ingestion/terraform.tfstate"
	terraform -chdir=$(DATA_INGESTION_DIR) validate
	terraform -chdir=$(DATA_INGESTION_DIR) apply -auto-approve \
		-var-file=./../variables/common.tfvars \
		-var-file=./../variables/$(ENV).tfvars


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

# Validate all Terraform configurations
validate-all:
	@echo "Validating all Terraform configurations..."
	terraform -chdir=$(SHARED_DIR) validate
	terraform -chdir=$(DATA_INGESTION_DIR) validate
	@echo "✅ All configurations valid!"

# Plan all changes without applying
plan-all:
	@echo "Planning shared infrastructure changes..."
	terraform -chdir=$(SHARED_DIR) plan \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars
	@echo "Planning data ingestion service changes..."
	terraform -chdir=$(DATA_INGESTION_DIR) plan \
		-var-file=$(VARIABLES_DIR)/common.tfvars \
		-var-file=$(VARIABLES_DIR)/$(ENV).tfvars

# Initialize all Terraform directories
init-all:
	@echo "Initializing all Terraform directories..."
	terraform -chdir=$(SHARED_DIR) init
	terraform -chdir=$(DATA_INGESTION_DIR) init
	@echo "✅ All directories initialized!"

# Destroy all infrastructure
destroy-all: check-aws-credentials
	@echo "Destroying shared infrastructure in $(ENV) environment..."
	terraform -chdir=$(SHARED_DIR) destroy -auto-approve \
		-var-file=./../variables/common.tfvars \
		-var-file=./../variables/$(ENV).tfvars
	@echo "Destroying data ingestion infrastructure in $(ENV) environment..."
	terraform -chdir=$(DATA_INGESTION_DIR) destroy -auto-approve \
		-var-file=./../variables/common.tfvars \
		-var-file=./../variables/$(ENV).tfvars
	@echo "✅ Teardown complete!"

# Clean up deployment artifacts
clean:
	@echo "Cleaning up deployment artifacts..."
	rm -rf $(PACKAGE_DIR)
	find infrastructure/terraform -name "*.tfplan" -type f -delete
	find infrastructure/terraform -name ".terraform" -type d -exec rm -rf {} +
	@echo "✅ Cleanup complete!"
