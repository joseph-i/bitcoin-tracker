# Bitcoin Price Tracker

A Go application that fetches Bitcoin prices from the CoinGecko API every 4 hours and stores them in a PostgreSQL database. The application runs in Docker containers for easy deployment.

## Features

- **Automated Price Fetching**: Retrieves Bitcoin prices every 4 hours
- **Database Storage**: Stores price history in PostgreSQL
- **Docker Support**: Fully containerized application
- **Multiple Run Modes**: Scheduler, one-time fetch, or display mode
- **Health Checks**: Database health monitoring
- **Resource Limits**: Optimized for production deployment

## Project Structure

```
bitcoin-tracker/
├── main.go              # Main application code
├── go.mod               # Go module definition
├── go.sum               # Go module checksums
├── Dockerfile           # Docker image configuration
├── docker-compose.yml   # Multi-container setup
├── Makefile            # Build and deployment commands
├── .dockerignore       # Docker build exclusions
└── README.md           # This file
```

## Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **Go** (version 1.21+) - only for local development

## Quick Start

### 1. Clone and Setup

```bash
# Create project directory
mkdir bitcoin-tracker
cd bitcoin-tracker

# Save the Go code to main.go
# Save the Docker files (Dockerfile, docker-compose.yml, etc.)
```

### 2. Start with Docker Compose

```bash
# Start all services (PostgreSQL + Bitcoin Tracker)
make docker-up

# Or manually:
docker-compose up -d
```

### 3. View Logs

```bash
# View application logs
make docker-logs

# Or manually:
docker-compose logs -f bitcoin-tracker
```

### 4. Check Database

```bash
# Access pgAdmin (optional)
# Open http://localhost:5050
# Login: admin@example.com / admin
```

## Usage

### Docker Compose (Recommended)

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f bitcoin-tracker

# Restart just the tracker
docker-compose restart bitcoin-tracker
```

### Manual Docker Commands

```bash
# Build the image
docker build -t bitcoin-tracker .

# Run with existing PostgreSQL
docker run -d \
  --name bitcoin-tracker \
  -e DATABASE_URL="postgres://user:pass@host:5432/dbname?sslmode=disable" \
  bitcoin-tracker
```

### Local Development

```bash
# Install dependencies
go mod download

# Run locally (requires local PostgreSQL)
export DATABASE_URL="postgres://bitcoin_user:bitcoin_pass@localhost:5432/bitcoin_db?sslmode=disable"
go run main.go

# Or build and run
go build -o bitcoin-tracker .
./bitcoin-tracker
```

## Application Modes

The application supports different modes via command line arguments:

```bash
# Scheduler mode (default) - runs every 4 hours
./bitcoin-tracker

# One-time fetch
./bitcoin-tracker fetch

# Display latest prices
./bitcoin-tracker display

# Scheduler mode (explicit)
./bitcoin-tracker scheduler
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://bitcoin_user:bitcoin_pass@localhost/bitcoin_db?sslmode=disable` |
| `TZ` | Timezone for timestamps | `UTC` |

### Database Schema

```sql
CREATE TABLE bitcoin_prices (
    id SERIAL PRIMARY KEY,
    price DECIMAL(15,2) NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW()
);
```

## Monitoring

### Health Checks

The PostgreSQL container includes health checks:

```bash
# Check container health
docker-compose ps

# Manual health check
docker exec bitcoin_db pg_isready -U bitcoin_user -d bitcoin_db
```

### Logs

```bash
# Application logs
docker-compose logs bitcoin-tracker

# Database logs
docker-compose logs postgres

# All logs
docker-compose logs
```

## Development

### Local Setup

```bash
# Install PostgreSQL locally
# Ubuntu/Debian:
sudo apt-get install postgresql postgresql-contrib

# macOS:
brew install postgresql

# Create database
sudo -u postgres createdb bitcoin_db
sudo -u postgres createuser bitcoin_user
sudo -u postgres psql -c "ALTER USER bitcoin_user WITH PASSWORD 'bitcoin_pass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bitcoin_db TO bitcoin_user;"
```

### Building

```bash
# Build binary
make build

# Build Docker image
make docker-build

# Run tests
make test

# Clean up
make clean
```

### Testing

```bash
# Run unit tests
go test -v ./...

# Test database connection
go run main.go fetch

# Display stored prices
go run main.go display
```

## Deployment

### Production Deployment

1. **Update Environment Variables**:
   ```bash
   # Update docker-compose.yml with production values
   POSTGRES_PASSWORD=your_secure_password
   DATABASE_URL=postgres://user:secure_pass@postgres:5432/bitcoin_db?sslmode=disable
   ```

2. **Use Docker Secrets** (for production):
   ```yaml
   # In docker-compose.yml
   secrets:
     db_password:
       file: ./secrets/db_password.txt
   ```

3. **Resource Limits**:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 512M
         cpus: '0.5'
   ```

### Cloud Deployment

The application can be deployed on:
- **AWS ECS/Fargate**
- **Google Cloud Run**
- **Azure Container Instances**
- **Kubernetes**

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   # Check if PostgreSQL is running
   docker-compose ps postgres
   
   # Check logs
   docker-compose logs postgres
   ```

2. **API Rate Limiting**
   ```bash
   # CoinGecko has rate limits - check logs
   docker-compose logs bitcoin-tracker
   ```

3. **Container Won't Start**
   ```bash
   # Check resource usage
   docker stats
   
   # Check container logs
   docker-compose logs
   ```

### Debugging

```bash
# Enter container shell
docker-compose exec bitcoin-tracker sh

# Check database from container
docker-compose exec postgres psql -U bitcoin_user -d bitcoin_db

# View table contents
SELECT * FROM bitcoin_prices ORDER BY timestamp DESC LIMIT 10;
```

## API Reference

### CoinGecko API

- **Endpoint**: `https://api.coingecko.com/api/v3/simple/price`
- **Parameters**: `ids=bitcoin&vs_currencies=usd`
- **Rate Limit**: 10-30 requests per minute
- **Documentation**: https://www.coingecko.com/en/api

## Security

- **Non-root User**: Application runs as non-root user in container
- **Resource Limits**: Memory and CPU limits configured
- **Network Isolation**: Containers communicate via internal network
- **Environment Variables**: Sensitive data via environment variables

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- Check the logs: `docker-compose logs`
- Review the troubleshooting section
- Create an issue in the repository
