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

ARG GOOSE_MODEL="claude-3-5-sonnet-latest"
ARG GOOSE_PROVIDER="anthropic"
ARG GOOSE_BIN_DIR="/usr/local/bin"

ENV 	GOOSE_MODEL=${GOOSE_MODEL} \
		GOOSE_PROVIDER=${GOOSE_PROVIDER} \
		GOOSE_BIN_DIR=${GOOSE_BIN_DIR} \
		PORT=3000

# Install certificates
# Install required dependencies
RUN apk add --no-cache \
    curl \
    bash \
    bzip2 \
    libxcb \
    dbus-libs \
    libstdc++ \
    libgcc \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Install goose with explicit error checking
RUN set -e && \
    echo "Installing goose with model: ${GOOSE_MODEL}, provider: ${GOOSE_PROVIDER}, bin_dir: ${GOOSE_BIN_DIR}" && \
    curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false bash && \
	 if [ ! -f "/usr/local/bin/goose" ]; then \
        echo "Goose binary not found"; \
        exit 1; \
    fi

# Creeate config.yaml
run mkdir ~/.config
run mkdir ~/.config/goose && touch ~/.config/goose/config.yaml
# Add GOOSE_MODEL and GOOSE_PROVIDER to config.yaml
RUN echo "GOOSE_MODEL: ${GOOSE_MODEL}" >> ~/.config/goose/config.yaml
RUN echo "GOOSE_PROVIDER: ${GOOSE_PROVIDER}" >> ~/.config/goose/config.yaml

RUN touch /usr/local/bin/

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/flock .

# Expose the default port
EXPOSE 3000

# Run the application
CMD ["./flock"]
