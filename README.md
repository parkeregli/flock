# Flock - AI-Powered GitHub Issue Handler

Flock is a Go-based service that automatically processes GitHub issues tagged with "AI" using the Goose AI agent. It can either clone repositories directly or work as a webhook service that responds to GitHub issue events.

## Features

- GitHub webhook integration for issue events
- Automatic processing of issues tagged with "AI"
- Support for direct repository cloning
- Dockerized deployment
- Health checking and automatic restart capabilities

## Prerequisites

- Go 1.22 or later
- Docker and Docker Compose (for containerized deployment)
- GitHub webhook secret
- GitHub access token (if required for private repositories)

## Configuration

The service can be configured using environment variables:

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `WEBHOOK_SECRET` | GitHub webhook secret for authentication | Yes | - |
| `GITHUB_TOKEN` | GitHub access token for repository access | No | - |
| `GITHUB_URL` | Direct repository URL for cloning (bypasses webhook mode) | No | - |
| `PORT` | Port for the webhook server | No | 3000 |
| `GOOSE_MODEL` | The AI model to use with Goose (e.g., gpt-4, claude-3) | Yes | - |
| `GOOSE_PROVIDER` | The AI provider to use (e.g., OpenAI, Anthropic) | Yes | - |
| `ANTHROPIC_API_KEY` | API key for Anthropic when using Claude models | No* | - |

\* Required if using Anthropic's Claude models

## Setup

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd flock
   ```

2. Copy the example environment file and configure your settings:
   ```bash
   cp .env.example .env
   ```

3. Edit the `.env` file with your configuration values.

## Deployment

### Using Docker Compose

1. Build and start the service:
   ```bash
   docker-compose up -d
   ```

2. Check the service status:
   ```bash
   docker-compose ps
   ```

### Manual Deployment

1. Build the application:
   ```bash
   go build -o flock ./src/main.go
   ```

2. Run the service:
   ```bash
   ./flock
   ```

## Usage

### Webhook Mode

1. Configure a GitHub webhook for your repository:
   - Webhook URL: `http://your-server:3000/webhook`
   - Content type: `application/json`
   - Secret: Your configured `WEBHOOK_SECRET`
   - Events: Select "Issues"

2. Create an issue in your repository and add the "AI" tag.
   The service will automatically:
   - Clone the repository
   - Process the issue using Goose AI
   - Clean up temporary files

### Direct Clone Mode

Set the `GITHUB_URL` environment variable to clone a specific repository:
```bash
export GITHUB_URL="https://github.com/username/repository.git"
./ai-maintainer
```

## Health Checks

The service includes Docker health checks that:
- Run every 30 seconds
- Verify the webhook endpoint is accessible
- Restart the service if health checks fail

## Development

The project structure is organized as follows:
```
.
├── src/
│   └── main.go          # Main application code
├── Dockerfile           # Docker build instructions
├── docker-compose.yml   # Docker Compose configuration
├── .env.example         # Example environment configuration
└── README.md           # This file
```
