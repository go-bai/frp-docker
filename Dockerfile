# FRP Docker Container - Enterprise Grade Implementation
# Supports both client and server modes with intelligent detection
# With NVIDIA GPU support
# Author: Claude Code AI Assistant
# License: MIT

FROM ubuntu:22.04 AS base

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages for security and functionality
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    vim \
    openssl \
    ca-certificates \
    tzdata \
    supervisor \
    openssh-server \
    net-tools \
    iputils-ping \
    iproute2 \
    gnupg2 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -g 1000 frp && \
    useradd -u 1000 -g frp -s /bin/bash -m frp

# Create necessary directories
RUN mkdir -p /app/frp /app/configs /app/logs /app/scripts \
    /etc/supervisor/conf.d \
    /var/run/sshd \
    /run/sshd && \
    chown -R frp:frp /app

WORKDIR /app

# Copy scripts
COPY scripts/ ./scripts/
COPY configs/ ./configs/

# Make scripts executable and create CLI symlink
RUN chmod +x scripts/* && \
    chown -R frp:frp /app && \
    ln -sf /app/scripts/frp_cli.sh /usr/local/bin/frp-cli

# Expose commonly used ports
EXPOSE 7000 7500 8080

# Set default environment variables
ENV FRP_MODE=client \
    FRP_VERSION=latest \
    FRP_SERVER_PORT=7000 \
    FRP_WEB_PORT=7500 \
    FRP_LOG_LEVEL=info \
    FRP_ARCH="" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /app/scripts/healthcheck.sh

# Add labels for NVIDIA Container Runtime
LABEL com.nvidia.volumes.needed="nvidia_driver" \
      com.nvidia.cuda.version="12.0"

# Do not switch user here - let entrypoint.sh handle it based on mode
# Server mode will run as frp user
# Client mode with supervisord needs root

# Entry point
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD []
