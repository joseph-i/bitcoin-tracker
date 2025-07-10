# Makefile
# Makefile for easy management of the Bitcoin tracker application

# Variables
BINARY_NAME=bitcoin-tracker
DOCKER_IMAGE=bitcoin-tracker
DOCKER_COMPOSE_FILE=docker-compose.yml

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  build          - Build the Go binary"
	@echo "  run            - Run the application locally"
	@echo "  docker-build   - Build the Docker image"
	@echo "  docker-up      - Start the application with Docker Compose"
	@echo "  docker-down    - Stop and remove Docker containers"
	@echo "  docker-logs    - View application logs"
	@echo "  clean          - Clean up built files"
	@echo "  test           - Run tests"

# Build the Go binary
.PHONY: build
build:
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) .

# Run the application locally (requires local PostgreSQL)
.PHONY: run
run: build
	@echo "Running $(BINARY_NAME)..."
	./$(BINARY_NAME)

# Build Docker image
.PHONY: docker-build
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE) .

# Start with Docker Compose
.PHONY: docker-up
docker-up:
	@echo "Starting services with Docker Compose..."
	docker-compose -f $(DOCKER_COMPOSE_FILE) up -d

# Stop Docker Compose services
.PHONY: docker-down
docker-down:
	@echo "Stopping services..."
	docker-compose -f $(DOCKER_COMPOSE_FILE) down

# View logs
.PHONY: docker-logs
docker-logs:
	@echo "Viewing logs..."
	docker-compose -f $(DOCKER_COMPOSE_FILE) logs -f bitcoin-tracker

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -f $(BINARY_NAME)
	docker system prune -f

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	go test -v ./...