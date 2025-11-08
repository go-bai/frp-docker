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
    lsb-release \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI for Docker-in-Docker support (socket mount)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install Golang 1.25.4
ARG GO_VERSION=1.25.4
ENV GOPATH=/go \
    PATH=/usr/local/go/bin:/go/bin:${PATH}

RUN set -ex && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then GO_ARCH="amd64"; fi && \
    if [ "$ARCH" = "arm64" ]; then GO_ARCH="arm64"; fi && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    mkdir -p /go/bin /go/pkg /go/src && \
    chmod -R 777 /go && \
    go version

# Install NVM (Node Version Manager)
ARG NVM_VERSION=v0.40.1
ENV NVM_DIR=/usr/local/nvm \
    NODE_VERSION=node

RUN set -ex && \
    mkdir -p $NVM_DIR && \
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o /tmp/nvm-install.sh && \
    bash /tmp/nvm-install.sh && \
    rm /tmp/nvm-install.sh && \
    echo 'export NVM_DIR="/usr/local/nvm"' >> /etc/bash.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/bash.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /etc/bash.bashrc

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

# Download and install FRP binaries at build time
ARG FRP_VERSION=latest
ARG TARGETARCH
RUN set -ex && \
    echo "Building for architecture: ${TARGETARCH:-amd64}" && \
    FRP_ARCH="${TARGETARCH:-amd64}" && \
    if [ "$FRP_ARCH" = "amd64" ]; then FRP_ARCH="amd64"; fi && \
    if [ "$FRP_ARCH" = "arm64" ]; then FRP_ARCH="arm64"; fi && \
    echo "Fetching latest FRP version..." && \
    if [ "$FRP_VERSION" = "latest" ]; then \
        FRP_VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")'); \
    fi && \
    echo "FRP Version: $FRP_VERSION" && \
    echo "FRP Architecture: $FRP_ARCH" && \
    FRP_VERSION_NUM=$(echo $FRP_VERSION | sed 's/^v//') && \
    DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION_NUM}_linux_${FRP_ARCH}.tar.gz" && \
    echo "Downloading from: $DOWNLOAD_URL" && \
    curl -fsSL "$DOWNLOAD_URL" -o /tmp/frp.tar.gz && \
    echo "Extracting FRP binaries..." && \
    tar -xzf /tmp/frp.tar.gz -C /tmp && \
    FRP_EXTRACT_DIR=$(find /tmp -maxdepth 1 -name "frp_*_linux_${FRP_ARCH}" -type d | head -n 1) && \
    echo "Installing from: $FRP_EXTRACT_DIR" && \
    cp "$FRP_EXTRACT_DIR/frps" /app/frp/ && \
    cp "$FRP_EXTRACT_DIR/frpc" /app/frp/ && \
    chmod +x /app/frp/frps /app/frp/frpc && \
    echo "$FRP_VERSION" > /app/frp/VERSION && \
    echo "Installed: $FRP_VERSION for $FRP_ARCH at $(date -u)" > /app/frp/INFO && \
    rm -rf /tmp/frp* && \
    chown -R frp:frp /app/frp && \
    echo "FRP installation completed" && \
    /app/frp/frps --version && \
    /app/frp/frpc --version

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
