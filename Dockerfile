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
FROM node:lts-bookworm

ARG GOOSE_MODEL
ARG GOOSE_PROVIDER
ARG GOOSE_BIN_DIR

ENV GOOSE_MODEL=${GOOSE_MODEL}
ENV GOOSE_PROVIDER=${GOOSE_PROVIDER}
ENV GOOSE_BIN_DIR=${GOOSE_BIN_DIR}

# Install certificates
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

RUN apt-get install -y libdbus-1-3

# Install goose with explicit error checking
RUN set -e && \
    echo "Installing goose with model: ${GOOSE_MODEL}, provider: ${GOOSE_PROVIDER}, bin dir: ${GOOSE_BIN_DIR}" && \
    curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh > download_cli.sh && \
    chmod +x download_cli.sh && \
    CONFIGURE=false ./download_cli.sh && \
    rm download_cli.sh && \
    if [ ! -f "${GOOSE_BIN_DIR}/goose" ]; then echo "Goose installation failed"; exit 1; fi

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
