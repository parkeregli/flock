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
FROM node:lts-bookworm-slim

ARG GOOSE_MODEL
ARG GOOSE_PROVIDER
ARG GOOSE_BIN_DIR

ENV GOOSE_MODEL=${GOOSE_MODEL}
ENV GOOSE_PROVIDER=${GOOSE_PROVIDER}
ENV GOOSE_BIN_DIR=${GOOSE_BIN_DIR}
# Install certificates
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Install goose
RUN curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false GOOSE_MODEL=${GOOSE_MODEL} GOOSE_PROVIDER=${GOOSE_PROVIDER} GOOSE_BIN_DIR=${GOOSE_BIN_DIR} bash

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/flock .

# Expose the default port
EXPOSE 3000

# Set environment variables
ENV PORT=3000
ENV PATH="/usr/bin:${PATH}"

# Run the application
CMD ["./flock"]
