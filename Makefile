.PHONY: lint lint_tf type_check validate_api test_logic deploy_dev deploy_prod clean check_all generate_api_docs

# Code quality
lint:
	pre-commit run --all-files

lint_tf:
	cd terraform && pre-commit run --config=.pre-commit-config-terraform.yaml --all-files

type_check:
	mypy app/ micropython/ tests/ --exclude 'micropython/libs/' --explicit-package-bases

validate_api:
	npx @stoplight/spectral-cli lint api-spec.yaml -r .spectral.yaml

test_logic:
	mkdir -p reports
	python3 -m pytest -s tests \
		-o asyncio_mode=auto \
		--junit-xml=reports/TEST-pytests.xml \
		--cov=app \
		--cov=micropython \
		--cov-report term \
		--cov-report xml:reports/py-coverage.cobertura.xml

# Deployment
tf_init_dev:
	@echo "Initializing Terraform..."
	cd terraform/environments/dev && \
	terraform init
	@echo "Terraform initialization complete!"

# Before deploying, ensure you have the correct AWS credentials and permissions set up.
deploy_dev:
	@echo "Starting dev deployment process..."
	mkdir -p lambda
	cd app/handlers/data_ingestion && \
	zip -j ../../../lambda/data_ingestion.zip data_ingestion.py
	cd terraform/environments/dev && \
	terraform init && \
	terraform validate && \
	terraform plan -out=tfplan && \
	terraform apply tfplan
	@echo "Dev deployment complete!"

deploy_prod:
	@echo "Starting production deployment process..."
	mkdir -p lambda
	cd app/handlers && \
	zip -r ../../lambda/data_ingestion.zip data_ingestion/
	cd terraform/environments/prod && \
	terraform init && \
	terraform validate && \
	terraform plan -out=tfplan && \
	terraform apply tfplan
	@echo "Production deployment complete!"

	clean:
	@echo "Cleaning up..."
	rm -rf lambda/*.zip
	find terraform -name "tfplan" -type f -delete
	@echo "Cleanup complete!"

# Documentation
generate_api_docs:
	mkdir -p docs/api
	npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html

# Mass check
check_all: lint type_check validate_api test_logic
