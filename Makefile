COMPOSE := docker compose
BRANCH  ?= develop

GITHUB_ORG := 100-hours-a-week
FE_REPO    := https://github.com/$(GITHUB_ORG)/5-team-service-fe.git
BE_REPO    := https://github.com/$(GITHUB_ORG)/5-team-service-be.git
AI_REPO    := https://github.com/$(GITHUB_ORG)/5-team-service-ai.git

.PHONY: help setup pull up down restart build logs logs-be logs-fe logs-ai \
        logs-nginx logs-mysql logs-redis ps clean redis-cli mysql-cli deps

help: ## Show available commands
	@echo ""
	@echo "Usage: make <command>"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Setup & Sync ────────────────────────────────────────────

setup: ## Clone all repos and prepare .env files
	@[ -d Frontend/.git ] || git clone -b $(BRANCH) $(FE_REPO) Frontend
	@[ -d Backend/.git ]  || git clone -b $(BRANCH) $(BE_REPO) Backend
	@[ -d AI/.git ]       || git clone -b $(BRANCH) $(AI_REPO) AI
	@[ -f .env ]          || cp .env.example .env
	@[ -f Backend/.env ]  || cp Backend/.env.example Backend/.env
	@[ -f AI/.env ]       || cp AI/.env.example AI/.env
	@echo ""
	@echo "Setup complete! Edit the following .env files with actual values:"
	@echo "  1. .env            — DB credentials (MySQL root password)"
	@echo "  2. Backend/.env    — JWT, Kakao OAuth, Zoom, AI API keys"
	@echo "  3. AI/.env         — Gemini API key, DB connection"
	@echo ""
	@echo "Then run: make up"

pull: ## Pull develop for all repos, rebuild and restart
	@echo "==> Pulling $(BRANCH) for all repos..."
	@git -C Frontend fetch origin && git -C Frontend checkout $(BRANCH) && git -C Frontend pull origin $(BRANCH)
	@git -C Backend  fetch origin && git -C Backend  checkout $(BRANCH) && git -C Backend  pull origin $(BRANCH)
	@git -C AI       fetch origin && git -C AI       checkout $(BRANCH) && git -C AI       pull origin $(BRANCH)
	@echo "==> Rebuilding and restarting..."
	$(COMPOSE) up --build -d
	@echo "Done. Run 'make ps' to check status."

# ─── Compose Lifecycle ───────────────────────────────────────

up: ## Build and start all services
	$(COMPOSE) up --build -d
	@echo "All services starting. Run 'make ps' or 'make logs' to monitor."

down: ## Stop all services
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

build: ## Rebuild all images (no restart)
	$(COMPOSE) build

clean: ## Stop and remove everything including volumes
	$(COMPOSE) down -v
	@echo "All containers and volumes removed."

# ─── Logs ────────────────────────────────────────────────────

logs: ## Follow all service logs
	$(COMPOSE) logs -f

logs-be: ## Follow backend logs
	$(COMPOSE) logs -f backend

logs-fe: ## Follow frontend logs
	$(COMPOSE) logs -f frontend

logs-ai: ## Follow AI logs
	$(COMPOSE) logs -f ai

logs-nginx: ## Follow nginx logs
	$(COMPOSE) logs -f nginx

logs-mysql: ## Follow MySQL logs
	$(COMPOSE) logs -f mysql

logs-redis: ## Follow Redis logs
	$(COMPOSE) logs -f redis

# ─── CLI Access ──────────────────────────────────────────────

redis-cli: ## Open Redis CLI
	$(COMPOSE) exec redis redis-cli

mysql-cli: ## Open MySQL CLI (doktoridb)
	$(COMPOSE) exec mysql sh -c 'mysql -u root -p$$MYSQL_ROOT_PASSWORD doktoridb'

# ─── Status ──────────────────────────────────────────────────

ps: ## Show service status
	$(COMPOSE) ps

# ─── Local IDE Development ───────────────────────────────────

deps: ## Start only MySQL + Redis (for local IDE development)
	$(COMPOSE) up -d mysql redis
	@echo ""
	@echo "  MySQL : localhost:3307"
	@echo "  Redis : localhost:6379"
	@echo ""
	@echo "Run your service locally in IDE."
