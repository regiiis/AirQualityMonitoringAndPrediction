.PHONY: all

lint:
	pre-commit run --all-files

type_check:
	mypy app/ micropython/ tests/

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
