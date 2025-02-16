# Build stage for Go application
FROM golang:1.22-alpine AS builder

# Install git and certificates (required for go mod download)
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY src/ ./src/

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/flock ./src/main.go

# Final stage
FROM node:lts-alpine

RUN adduser -D appuser

ARG GOOSE_MODEL="claude-3-5-sonnet-latest"
ARG GOOSE_PROVIDER="anthropic"

ENV 	GOOSE_MODEL=${GOOSE_MODEL} \
		GOOSE_PROVIDER=${GOOSE_PROVIDER} \
		HOME="/home/appuser" \
		PORT=3000 \
		PATH="/home/appuser/.local/bin:${PATH}"

# Install certificates
# Install required dependencies
RUN apk add --no-cache \
    curl \
    bash \
    ca-certificates

USER appuser

WORKDIR /home/appuser

RUN mkdir -p /home/appuser/.local/bin

# Install goose with explicit error checking
RUN set -e && \
    echo "Installing goose with model: ${GOOSE_MODEL}, provider: ${GOOSE_PROVIDER} && \
    curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh > download_cli.sh && \
    chmod +x download_cli.sh && \
    CONFIGURE=false ./download_cli.sh && \
    rm download_cli.sh && \
    if [ ! -f "/home/appuser/.local/bin/goose" ]; then echo "Goose installation failed"; exit 1; fi

WORKDIR /app
USER root
RUN chown -R appuser:appuser /app

# Copy the binary from builder
COPY --from=builder /app/flock .

USER appuser

# Expose the default port
EXPOSE 3000

# Run the application
CMD ["./flock"]
