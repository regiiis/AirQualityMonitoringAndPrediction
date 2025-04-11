.PHONY: all lint type_check validate_api check_api_breaking_changes generate_api_docs

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

generate_api_docs:
	mkdir -p docs/api
	npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html

# Combined check target
check_all: lint type_check validate_api test_logic
