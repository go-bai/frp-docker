# FRP Docker Container - Enterprise Grade Implementation
# Supports both client and server modes with intelligent detection
# Author: Claude Code AI Assistant
# License: MIT

FROM alpine:3.18 AS base

# Install essential packages for security and functionality
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create non-root user for security
RUN addgroup -g 1000 frp && \
    adduser -D -u 1000 -G frp -s /bin/bash frp

# Create necessary directories
RUN mkdir -p /app/frp /app/configs /app/logs /app/scripts && \
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
    LC_ALL=C.UTF-8

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /app/scripts/healthcheck.sh

# Switch to non-root user
USER frp

# Entry point
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD []