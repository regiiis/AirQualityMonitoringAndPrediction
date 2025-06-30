.PHONY: test clean install-deps

# Test configuration
PYTHON := python3
TEST_DIR := tests
REPORTS_DIR := reports

# Run tests with coverage
test:
    mkdir -p $(REPORTS_DIR)
    $(PYTHON) -m pytest $(TEST_DIR) \
        --verbose \
		--tb=short \
        --junit-xml=$(REPORTS_DIR)/consolidation-tests.xml \
        --cov=. \
        --cov-report=term-missing \
        --cov-report=xml:$(REPORTS_DIR)/consolidation-coverage.xml
