PYTHON ?= python

.PHONY: install lint test test-integration verify postgres-up postgres-down

install:
	$(PYTHON) -m pip install -r requirements-dev.txt

lint:
	$(PYTHON) -m ruff check .
	$(PYTHON) -m ruff format --check .

test:
	$(PYTHON) -m pytest -m "not integration"

test-integration:
	$(PYTHON) -m pytest -m integration

verify: lint test test-integration

postgres-up:
	docker compose -f compose.test.yml up -d --wait

postgres-down:
	docker compose -f compose.test.yml down --volumes
