.PHONY: lint lint_tf type_check validate_api test_logic test_data_consolidation deploy_dev deploy_prod clean generate_api_docs

# Code quality
lint:
	pre-commit run --all-files

lint_tf:
	cd infrastructure/ && pre-commit run --config=.pre-commit-config-terraform.yaml --all-files

type_check:
	mypy app/ micropython/ tests/ --exclude 'micropython/libs/' --explicit-package-bases --show-error-codes --show-traceback

validate_api:
	npx @stoplight/spectral-cli lint api-spec.yaml -r .spectral.yaml

test_logic:
	@echo "Running unit tests..."
	mkdir -p reports
	python3 -m pytest -s tests \
		-o asyncio_mode=auto \
		--junit-xml=reports/TEST-pytests.xml \
		--cov=app \
		--cov=micropython \
		--cov-report term \
		--cov-report xml:reports/py-coverage.cobertura.xml
	@echo "Running data consolidation tests..."
	$(MAKE) -C app/data_engineering/data_consolidation test

# Data consolidation tests only
test_data_consolidation:
	$(MAKE) -C app/data_engineering/data_consolidation test

# Infrastructure Deployments - call into infrastructure Makefile
deploy_dev:
	@echo "Starting dev deployment process..."
	$(MAKE) -f infrastructure/deployment/Makefile deploy-all ENV=dev

destroy_dev:
	@echo "Starting dev destroyment process..."
	$(MAKE) -f infrastructure/deployment/Makefile destroy-all ENV=dev

deploy_prod:
	@echo "Starting production deployment process..."
	$(MAKE) -C infrastructure/deployment deploy-all ENV=prod

destroy_prod:
	@echo "Starting dev destroyment process..."
	$(MAKE) -f infrastructure/deployment/Makefile destroy-all ENV=prod

# Clean up deployment artifacts
clean:
	$(MAKE) -C infrastructure/deployment clean
	rm -rf reports

# Documentation
generate_api_docs:
	mkdir -p docs/api
	npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html
