# Kamloic Trust Bank

A modern banking application with real-time features.

## Features

- User registration and login
- Account balance management
- Money transfers between users
- Real-time notifications via WebSocket
- Session management with Redis
- PostgreSQL for data persistence

## Quick Start

```bash
# Clone and run
cd banking-demo
docker compose up -d --build

# Check status
docker compose ps
```

Access the application at `http://localhost:3000`

## Architecture

- **Frontend**: React with Tailwind CSS
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL
- **Cache/Sessions**: Redis
- **Real-time**: WebSocket notifications

## Development

```bash
# View logs
docker compose logs -f

# Stop services
docker compose down
```
