#!/bin/bash
##
## FRP Server Configuration Manager - Enterprise Grade
## Automatic configuration generation with security best practices
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Source common functions if available
if [[ -f "/app/scripts/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "/app/scripts/common.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    error_exit() { echo "[ERROR] $*" >&2; exit 1; }
fi

# Global variables
if [[ -z "${CONFIG_DIR:-}" ]]; then
    readonly CONFIG_DIR="/app/configs"
fi
readonly AUTH_FILE="${CONFIG_DIR}/server_auth.txt"
readonly SERVER_CONFIG="${CONFIG_DIR}/frps.yaml"

# Generate secure authentication token
generate_auth_token() {
    local token_length=32
    local charset='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

    if command -v openssl >/dev/null 2>&1; then
        # Use OpenSSL for cryptographically secure random token
        openssl rand -base64 $((token_length * 3 / 4)) | tr -d '/+=' | head -c "${token_length}"
    elif command -v xxd >/dev/null 2>&1 && [[ -c /dev/urandom ]]; then
        # Use /dev/urandom with xxd
        dd if=/dev/urandom bs=1 count="${token_length}" 2>/dev/null | xxd -p | head -c "${token_length}"
    else
        # Fallback to basic random (less secure)
        log_warn "Using fallback random generation - consider installing openssl for better security"
        for ((i=0; i<token_length; i++)); do
            echo -n "${charset:$((RANDOM % ${#charset})):1}"
        done
    fi
}

# Create server configuration
create_server_config() {
    local auth_token="$1"
    local server_port="${FRP_SERVER_PORT:-7000}"
    local web_port="${FRP_WEB_PORT:-7500}"
    local log_level="${FRP_LOG_LEVEL:-info}"

    log_info "Creating server configuration..."

    # Create configuration directory
    mkdir -p "${CONFIG_DIR}"

    # Generate server configuration
    cat > "${SERVER_CONFIG}" << EOF
# FRP Server Configuration - Auto Generated (YAML Format)
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Container: FRP Docker v1.0.0

# Basic server settings
bindAddr: "0.0.0.0"
bindPort: ${server_port}

# Authentication
auth:
  method: token
  token: "${auth_token}"

# Web dashboard
webServer:
  addr: "0.0.0.0"
  port: ${web_port}
  user: "admin"
  password: "${auth_token}"

# Logging
log:
  to: "/app/logs/frps.log"
  level: "${log_level}"
  maxDays: 7

# Transport settings
transport:
  tcpMux: true

# Security settings - simplified
allowPorts:
  - start: 2000
    end: 50000

EOF

    log_info "Server configuration created: ${SERVER_CONFIG}"
}

# Save authentication information
save_auth_info() {
    local auth_token="$1"
    local server_port="${FRP_SERVER_PORT:-7000}"
    local web_port="${FRP_WEB_PORT:-7500}"
    local server_ip

    # Try to detect server IP
    if command -v hostname >/dev/null 2>&1; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")
    else
        server_ip="YOUR_SERVER_IP"
    fi

    # Save auth info to file
    cat > "${AUTH_FILE}" << EOF
# FRP Server Authentication Information
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Server IP: ${server_ip}
Server Port: ${server_port}
Web Dashboard Port: ${web_port}
Authentication Token: ${auth_token}

# Client Connection Command:
docker run -e FRP_MODE=client -e FRP_SERVER_ADDR=${server_ip} -e FRP_SERVER_PORT=${server_port} -e FRP_TOKEN=${auth_token} frp-docker

# Web Dashboard URL:
http://${server_ip}:${web_port}
Username: admin
Password: ${auth_token}

# Manual Client Configuration:
[common]
server_addr = ${server_ip}
server_port = ${server_port}
token = ${auth_token}
EOF

    log_info "Authentication information saved: ${AUTH_FILE}"
}

# Display connection information
display_connection_info() {
    local auth_token="$1"
    local server_port="${FRP_SERVER_PORT:-7000}"
    local web_port="${FRP_WEB_PORT:-7500}"

    echo ""
    echo "=========================================="
    echo "   FRP SERVER STARTED SUCCESSFULLY"
    echo "=========================================="
    echo ""
    echo "🔑 Authentication Token: ${auth_token}"
    echo ""
    echo "📡 Server Details:"
    echo "   - Server Port: ${server_port}"
    echo "   - Dashboard Port: ${web_port}"
    echo "   - Dashboard User: admin"
    echo "   - Dashboard Pass: ${auth_token}"
    echo ""
    echo "🚀 Client Connection:"
    echo "   docker run -e FRP_MODE=client \\"
    echo "              -e FRP_SERVER_ADDR=YOUR_SERVER_IP \\"
    echo "              -e FRP_SERVER_PORT=${server_port} \\"
    echo "              -e FRP_TOKEN=${auth_token} \\"
    echo "              --network host \\"
    echo "              frp-docker"
    echo ""
    echo "📊 Web Dashboard:"
    echo "   http://YOUR_SERVER_IP:${web_port}"
    echo "   Username: admin"
    echo "   Password: ${auth_token}"
    echo ""
    echo "📋 Configuration saved to: ${AUTH_FILE}"
    echo "=========================================="
    echo ""
}

# Initialize server configuration
initialize_server_config() {
    local auth_token
    local existing_token

    log_info "Initializing FRP server configuration..."

    # Check if auth file exists and has a token
    if [[ -f "${AUTH_FILE}" ]]; then
        existing_token=$(grep "Authentication Token:" "${AUTH_FILE}" 2>/dev/null | cut -d' ' -f3- || echo "")
        if [[ -n "${existing_token}" ]] && [[ ${#existing_token} -ge 16 ]]; then
            log_info "Using existing authentication token"
            auth_token="${existing_token}"
        fi
    fi

    # Generate new token if needed
    if [[ -z "${auth_token:-}" ]]; then
        log_info "Generating new authentication token..."
        auth_token=$(generate_auth_token)

        if [[ -z "${auth_token}" ]] || [[ ${#auth_token} -lt 16 ]]; then
            error_exit "Failed to generate secure authentication token"
        fi

        log_info "Generated secure authentication token (${#auth_token} characters)"
    fi

    # Create configuration
    create_server_config "${auth_token}"
    save_auth_info "${auth_token}"
    display_connection_info "${auth_token}"

    log_info "Server initialization completed successfully"
}

# Health check function
check_server_health() {
    local config_file="${SERVER_CONFIG}"
    local auth_file="${AUTH_FILE}"

    if [[ ! -f "${config_file}" ]]; then
        echo "Server configuration missing"
        return 1
    fi

    if [[ ! -f "${auth_file}" ]]; then
        echo "Authentication file missing"
        return 1
    fi

    echo "Server configuration OK"
    return 0
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-init}" in
        "init")
            initialize_server_config
            ;;
        "health"|"check")
            check_server_health
            ;;
        *)
            echo "Usage: $0 {init|health}"
            exit 1
            ;;
    esac
fi