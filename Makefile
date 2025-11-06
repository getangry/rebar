.PHONY: help build up down restart logs shell test migrate seed clean

# Default target
help:
	@echo "Rebar - ReBAC API + React Frontend"
	@echo ""
	@echo "Available targets:"
	@echo "  make build       - Build Docker images"
	@echo "  make up          - Start all services"
	@echo "  make down        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make logs        - View API logs"
	@echo "  make logs-web    - View web frontend logs"
	@echo "  make logs-all    - View all logs"
	@echo "  make shell       - Open Rails console"
	@echo "  make test        - Run all tests"
	@echo "  make test-unit   - Run unit tests only"
	@echo "  make test-int    - Run integration tests only"
	@echo "  make migrate     - Run database migrations"
	@echo "  make seed        - Seed database with sample data"
	@echo "  make clean       - Remove all containers and volumes"
	@echo "  make routes      - Show all API routes"
	@echo "  make curl-demo   - Run curl API demo"
	@echo ""

# Docker operations
build:
	docker-compose build

up:
	docker-compose up -d
	@echo "✅ Services started!"
	@echo ""
	@echo "🌐 Web UI:  http://localhost:8080"
	@echo "🔌 API:     http://localhost:3000"
	@echo "🗄️  Postgres: localhost:5432"
	@echo ""
	@echo "Run 'make logs-all' to view logs"

down:
	docker-compose down

restart: down up

logs:
	docker-compose logs -f api

logs-web:
	docker-compose logs -f web

logs-all:
	docker-compose logs -f

# Development
shell:
	docker-compose run --rm api bundle exec rails console

migrate:
	docker-compose run --rm migrate

seed:
	docker-compose run --rm api bundle exec rails db:seed

routes:
	docker-compose run --rm api bundle exec rails routes

# Testing
test:
	docker-compose run --rm api bundle exec rspec --format documentation

test-unit:
	docker-compose run --rm api bundle exec rspec spec/models spec/services --format documentation

test-int:
	docker-compose run --rm api bundle exec rspec spec/integration spec/requests --format documentation

test-coverage:
	docker-compose run --rm api bundle exec rspec --format documentation --format html --out tmp/rspec_results.html

test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/path/to/file_spec.rb"; \
		exit 1; \
	fi
	docker-compose run --rm api bundle exec rspec $(FILE) --format documentation

# Database
db-reset:
	docker-compose run --rm api bundle exec rails db:drop db:create db:migrate

db-console:
	docker-compose exec postgres psql -U postgres -d rebar_development

# Cleanup
clean:
	docker-compose down -v
	docker system prune -f

clean-all: clean
	docker volume rm rebar_postgres rebar_bundle || true

# API Testing
curl-demo:
	@echo "=== Rebar API Demo with curl ==="
	@echo ""
	@echo "1. Creating alice as owner of doc 'report-1'..."
	@curl -s -X POST http://localhost:3000/api/tuples \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"ns":"doc","id":"report-1","relation":"owner","subj_ns":"user","subj_id":"alice"}' | jq
	@echo ""
	@echo "2. Checking if alice can view report-1..."
	@curl -s -X POST http://localhost:3000/api/auth/check \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"subj_ns":"user","subj_id":"alice","permission":"viewer","obj_ns":"doc","obj_id":"report-1"}' | jq
	@echo ""
	@echo "3. Getting explanation of alice's permission..."
	@curl -s -X POST http://localhost:3000/api/auth/explain \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"subj_ns":"user","subj_id":"alice","permission":"viewer","obj_ns":"doc","obj_id":"report-1"}' | jq
	@echo ""
	@echo "4. Adding bob to engineering group..."
	@curl -s -X POST http://localhost:3000/api/tuples \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"ns":"group","id":"engineering","relation":"member","subj_ns":"user","subj_id":"bob"}' | jq
	@echo ""
	@echo "5. Giving engineering group viewer access to report-1..."
	@curl -s -X POST http://localhost:3000/api/tuples \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"ns":"doc","id":"report-1","relation":"viewer","subj_ns":"group","subj_id":"engineering","subj_rel":"member"}' | jq
	@echo ""
	@echo "6. Checking if bob can view report-1..."
	@curl -s -X POST http://localhost:3000/api/auth/check \
		-H "Content-Type: application/json" \
		-H "X-Service-Id: dev" \
		-H "X-Tenant: demo" \
		-d '{"subj_ns":"user","subj_id":"bob","permission":"viewer","obj_ns":"doc","obj_id":"report-1"}' | jq
	@echo ""
	@echo "Demo complete! Check out USAGE.md for more examples."

# Development utilities
fmt:
	docker-compose run --rm api bundle exec rubocop -A

lint:
	docker-compose run --rm api bundle exec rubocop

audit:
	docker-compose run --rm api bundle exec bundle-audit check --update

security:
	docker-compose run --rm api bundle exec brakeman -q

check: lint test

# Documentation
docs:
	@echo "Documentation files:"
	@echo "  - README.md      - Project overview"
	@echo "  - USAGE.md       - API usage guide with examples"
	@echo "  - config/auth_schema.yml - Permission schema"

# Health check
health:
	@echo "Checking API health..."
	@curl -s http://localhost:3000/up | jq || echo "API is not responding"
	@echo ""
	@echo "Checking database..."
	@docker-compose exec postgres pg_isready -U postgres || echo "Database is not responding"

# Quick start
quickstart: build up migrate
	@echo ""
	@echo "✅ Rebar is ready!"
	@echo ""
	@echo "🌐 Web UI:  http://localhost:8080"
	@echo "🔌 API:     http://localhost:3000"
	@echo ""
	@echo "Try these commands:"
	@echo "  make curl-demo   - Run API demo"
	@echo "  make test        - Run tests"
	@echo "  make logs-all    - View all logs"
	@echo ""
	@echo "See USAGE.md for full documentation"
