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
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

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
