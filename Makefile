.PHONY: all lint type_check validate_api check_api_breaking_changes generate_api_docs

lint:
	pre-commit run --all-files

type_check:
	mypy app/ micropython/ tests/ --exclude 'micropython/libs/'

validate_api:
	npx @stoplight/spectral-cli lint api-spec.yaml -r .spectral.yaml

test_logic:
	mkdir -p reports
	python3 -m pytest -s tests/logic \
		-o asyncio_mode=auto \
		--junit-xml=reports/TEST-pytests.xml \
		--cov=app \
		--cov-report term \
		--cov-report xml:reports/py-coverage.cobertura.xml

test_cdk:
	mkdir -p reports
	PYTHONPATH=$(PWD)/stacks python3 -m pytest -v -s tests/cdk --junit-xml=reports/TEST-pytests.xml --cov=stacks \
	--cov-report term --cov-report xml:reports/py-coverage.cobertura.xml --cov-fail-under=80

generate_api_docs:
	mkdir -p docs/api
	npx @redocly/cli build-docs api-spec.yaml -o docs/api/index.html

# Combined check target
check_all: lint type_check validate_api
