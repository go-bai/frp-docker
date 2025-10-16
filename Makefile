# FRP Docker - Enterprise Grade Makefile
# Comprehensive build and deployment automation
# Author: Claude Code AI Assistant

.PHONY: build test clean help server client sidecar logs shell

# Default variables
IMAGE_NAME ?= frp-docker
VERSION ?= latest
SERVER_PORT ?= 7000
WEB_PORT ?= 7500

# Default target
.DEFAULT_GOAL := help

# Build Docker image
build: ## Build the FRP Docker image
	@echo "🔨 Building FRP Docker image..."
	@chmod +x build.sh scripts/*.sh
	@./build.sh build
	@echo "✅ Build completed successfully"

# Run comprehensive tests
test: ## Run comprehensive test suite
	@echo "🧪 Running test suite..."
	@./build.sh test
	@echo "✅ Tests completed"

# Build and test
all: ## Build image and run tests (default)
	@echo "🚀 Building and testing FRP Docker..."
	@chmod +x build.sh scripts/*.sh
	@./build.sh all

# Start FRP server
server: ## Start FRP server container
	@echo "🖥️  Starting FRP server..."
	@docker run -d \
		--name frp-server \
		--network host \
		--restart unless-stopped \
		-e FRP_MODE=server \
		-e FRP_SERVER_PORT=$(SERVER_PORT) \
		-e FRP_WEB_PORT=$(WEB_PORT) \
		-v frp_server_data:/app/configs \
		-v frp_server_logs:/app/logs \
		$(IMAGE_NAME)
	@echo "✅ FRP server started"
	@echo "📋 Get auth token: make server-info"

# Start FRP client
client: ## Start FRP client container (interactive)
	@echo "📱 Starting FRP client..."
	@docker run -it --rm \
		--name frp-client \
		-e FRP_MODE=client \
		$(IMAGE_NAME) shell

# Start FRP client as daemon
client-daemon: ## Start FRP client as daemon
	@echo "📱 Starting FRP client daemon..."
	@read -p "Server IP: " SERVER_IP; \
	read -p "Auth Token: " TOKEN; \
	docker run -d \
		--name frp-client \
		--network host \
		--restart unless-stopped \
		-e FRP_MODE=client \
		-e FRP_SERVER_ADDR=$$SERVER_IP \
		-e FRP_SERVER_PORT=$(SERVER_PORT) \
		-e FRP_TOKEN=$$TOKEN \
		-v frp_client_data:/app/configs \
		-v frp_client_logs:/app/logs \
		$(IMAGE_NAME)

# Sidecar example
sidecar: ## Start sidecar example with nginx
	@echo "🚗 Starting sidecar example..."
	@docker-compose -f examples/sidecar.yml up -d
	@echo "✅ Sidecar example started"
	@echo "📋 Configure tunnels: make sidecar-shell"

# Show server authentication info
server-info: ## Show server authentication information
	@echo "🔑 Server Authentication Information:"
	@docker exec frp-server cat /app/configs/server_auth.txt 2>/dev/null || echo "❌ Server not running or auth file not found"

# Show server logs
server-logs: ## Show server logs
	@echo "📋 Server Logs:"
	@docker logs -f frp-server

# Show client logs
client-logs: ## Show client logs
	@echo "📋 Client Logs:"
	@docker logs -f frp-client

# Access server shell
server-shell: ## Access server shell
	@docker exec -it frp-server /bin/bash

# Access client CLI
client-shell: ## Access client CLI
	@docker exec -it frp-client /app/scripts/frp_cli.sh

# Access sidecar CLI
sidecar-shell: ## Access sidecar CLI
	@docker exec -it frp-sidecar-example /app/scripts/frp_cli.sh

# Stop and remove all containers
stop: ## Stop and remove all FRP containers
	@echo "🛑 Stopping FRP containers..."
	@docker stop frp-server frp-client 2>/dev/null || true
	@docker rm frp-server frp-client 2>/dev/null || true
	@docker-compose -f examples/sidecar.yml down 2>/dev/null || true
	@echo "✅ All containers stopped"

# Clean up everything
clean: ## Clean up containers, images, and volumes
	@echo "🧹 Cleaning up everything..."
	@./build.sh clean
	@docker volume rm frp_server_data frp_server_logs frp_client_data frp_client_logs 2>/dev/null || true
	@echo "✅ Cleanup completed"

# Development setup
dev-setup: ## Setup development environment
	@echo "⚙️  Setting up development environment..."
	@chmod +x build.sh scripts/*.sh
	@echo "✅ Development environment ready"
	@echo "📋 Run 'make build' to build the image"

# Show container status
status: ## Show FRP container status
	@echo "📊 Container Status:"
	@docker ps -a --filter "name=frp" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "📦 Volumes:"
	@docker volume ls --filter "name=frp" --format "table {{.Name}}\t{{.Size}}"

# Show help
help: ## Show this help message
	@echo "FRP Docker - Enterprise Grade Container"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make build          # Build the Docker image"
	@echo "  make server         # Start FRP server"
	@echo "  make client         # Start interactive client"
	@echo "  make server-info    # Get server auth token"
	@echo "  make sidecar        # Start sidecar example"
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  SERVER_PORT=$(SERVER_PORT)"
	@echo "  WEB_PORT=$(WEB_PORT)"

# Docker Compose shortcuts
compose-server: ## Start server using Docker Compose
	@docker-compose -f examples/server.yml up -d

compose-client: ## Start client using Docker Compose
	@docker-compose -f examples/client.yml up -d

compose-logs: ## Show Docker Compose logs
	@docker-compose -f examples/server.yml logs -f 2>/dev/null || docker-compose -f examples/client.yml logs -f

compose-down: ## Stop Docker Compose services
	@docker-compose -f examples/server.yml down 2>/dev/null || true
	@docker-compose -f examples/client.yml down 2>/dev/null || true
	@docker-compose -f examples/sidecar.yml down 2>/dev/null || true