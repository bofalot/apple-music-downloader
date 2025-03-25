# ===== Build Stage =====
FROM golang:1.23.1 AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    git \
    zlib1g-dev \
    curl \
    ffmpeg

# Clone and build GPAC
WORKDIR /gpac_build
RUN git clone https://github.com/gpac/gpac.git gpac_public && cd gpac_public \
    && ./configure --static-bin \
    && make && make install

# Enable Go Modules
ENV GO111MODULE=on

# Copy application source
WORKDIR /app/server
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the Go binary
RUN go build -o app

# ===== Runtime Stage =====
FROM ubuntu:latest AS runtime

# Install required runtime dependencies
RUN apt-get update && apt-get install -y \
    zlib1g \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Copy GPAC binaries from build stage
COPY --from=build /usr/local/bin/ /usr/local/bin/
COPY --from=build /gpac_build/gpac_public/bin/gcc /usr/local/bin/

# Ensure GPAC is in the PATH
ENV PATH="/usr/local/bin:$PATH"

# Copy built application from build stage
WORKDIR /app/server
COPY --from=build /app/server/app .

# Set entrypoint to allow runtime arguments
ENTRYPOINT ["/app/server/app"]
