.PHONY: all lint type_check validate_api check_api_breaking_changes generate_api_docs


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
deploy:
	mkdir -p lambda
	cd app/handlers
	zip -r ../../../lambda/validator.zip validator.py
	zip -r ../../../lambda/storage.zip storage.py
	cd ../../..

# Documentation
generate_api_docs:
	mkdir -p docs/api
	npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html

# Combined check target
check_all: lint type_check validate_api test_logic
