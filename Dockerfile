# Dockerfile
# Use the official Go image as build environment
# golang:1.21-alpine provides a lightweight Go environment
FROM golang:1.21-alpine AS builder

# Install git and other dependencies needed for building
# Git is needed to fetch Go modules
RUN apk add --no-cache git

# Set the working directory inside the container
WORKDIR /app

# Copy go.mod and go.sum files first for better Docker layer caching
# This allows Docker to cache the module downloads if dependencies haven't changed
COPY go.mod go.sum ./

# Download Go modules
# This step is cached if go.mod and go.sum haven't changed
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# CGO_ENABLED=0 creates a statically linked binary
# GOOS=linux ensures we build for Linux regardless of host OS
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bitcoin-tracker .

# Use a minimal base image for the final container
# alpine:latest is a security-focused, lightweight Linux distribution
FROM alpine:latest

# Install ca-certificates for HTTPS requests
# tzdata for proper timezone handling
RUN apk --no-cache add ca-certificates tzdata

# Create a non-root user for security
# Running as non-root is a security best practice
RUN addgroup -g 1001 appgroup && \
    adduser -D -s /bin/sh -u 1001 -G appgroup appuser

# Set the working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/bitcoin-tracker .

# Change ownership of the application to the non-root user
RUN chown appuser:appgroup /app/bitcoin-tracker

# Switch to the non-root user
USER appuser

# Expose port (not needed for this app, but good practice)
# EXPOSE 8080

# Command to run the application
# This starts the scheduler by default
CMD ["./bitcoin-tracker"]

---

# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL database service
  postgres:
    image: postgres:15-alpine
    container_name: bitcoin_db
    restart: unless-stopped
    
    # Environment variables for PostgreSQL setup
    environment:
      # Database configuration
      POSTGRES_DB: bitcoin_db
      POSTGRES_USER: bitcoin_user
      POSTGRES_PASSWORD: bitcoin_pass
      
      # Performance tuning
      POSTGRES_INITDB_ARGS: "--data-checksums"
    
    # Volume for persistent data storage
    # This ensures data survives container restarts
    volumes:
      - postgres_data:/var/lib/postgresql/data
      # Optional: mount initialization scripts
      # - ./init-scripts:/docker-entrypoint-initdb.d
    
    # Port mapping (optional, for external access)
    ports:
      - "5432:5432"
    
    # Health check to ensure database is ready
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bitcoin_user -d bitcoin_db"]
      interval: 10s
      timeout: 5s
      retries: 5
    
    # Resource limits (optional)
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  # Bitcoin price tracker application
  bitcoin-tracker:
    build: .
    container_name: bitcoin_tracker
    restart: unless-stopped
    
    # Environment variables for the application
    environment:
      # Database connection string
      DATABASE_URL: "postgres://bitcoin_user:bitcoin_pass@postgres:5432/bitcoin_db?sslmode=disable"
      
      # Timezone setting
      TZ: "UTC"
    
    # Wait for PostgreSQL to be ready before starting
    depends_on:
      postgres:
        condition: service_healthy
    
    # Resource limits
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M

  # Optional: pgAdmin for database management
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: bitcoin_pgadmin
    restart: unless-stopped
    
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
    
    ports:
      - "5050:80"
    
    depends_on:
      - postgres
    
    volumes:
      - pgadmin_data:/var/lib/pgadmin

# Named volumes for persistent data
volumes:
  postgres_data:
    driver: local
  pgadmin_data:
    driver: local

# Network configuration (optional)
networks:
  default:
    driver: bridge

---

# go.mod
module bitcoin-tracker

go 1.21

require (
    github.com/lib/pq v1.10.9
)

---

# go.sum
github.com/lib/pq v1.10.9 h1:YXG7RB+JIjhP29X+OtkiDnYaXQwpS4JEWq7dtCCRUEw=
github.com/lib/pq v1.10.9/go.mod h1:AlVN5x4E4T544tWzH6hKfbfQvm3HdbOxrmggDNAPY9o=

---

# .dockerignore
# Ignore files that shouldn't be included in the Docker build context
# This reduces build time and image size

# Binaries
bitcoin-tracker

# Go build artifacts
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool
*.out

# Go workspace files
go.work
go.work.sum

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Docker files (don't include in build context)
Dockerfile
docker-compose.yml
.dockerignore

# Git
.git/
.gitignore

# Documentation
README.md
*.md

---

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