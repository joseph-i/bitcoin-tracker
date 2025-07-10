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