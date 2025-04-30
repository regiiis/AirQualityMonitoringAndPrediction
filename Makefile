.PHONY: lint lint_tf type_check validate_api test_logic deploy_dev deploy_prod clean check_all generate_api_docs

# Code quality
lint:
    pre-commit run --all-files

lint_tf:
    cd terraform && pre-commit run --config=.pre-commit-config-terraform.yaml --all-files

type_check:
    mypy app/ micropython/ tests/ --exclude 'micropython/libs/' --explicit-package-bases --show-error-codes --show-traceback

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

# Infrastructure Deployments - call into infrastructure Makefile
deploy_dev:
    @echo "Starting dev deployment process..."
    $(MAKE) -C infrastructure/deployment deploy-all ENV=dev

deploy_shared_dev:
    $(MAKE) -C infrastructure/deployment deploy-shared ENV=dev

deploy_data_ingestion_dev:
    $(MAKE) -C infrastructure/deployment deploy-data-ingestion ENV=dev

deploy_prod:
    @echo "Starting production deployment process..."
    $(MAKE) -C infrastructure/deployment deploy-all ENV=prod

# Show infrastructure endpoints
show_endpoints:
    $(MAKE) -C infrastructure/deployment show-endpoints

# Clean up deployment artifacts
clean:
    $(MAKE) -C infrastructure/deployment clean
    rm -rf reports

# Documentation
generate_api_docs:
    mkdir -p docs/api
    npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html

# Mass check
check_all: lint type_check validate_api test_logic
