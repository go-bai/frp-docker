#!/bin/bash
##
## FRP Client Configuration Manager - Enterprise Grade
## Dynamic client configuration with CLI integration
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
readonly CLIENT_CONFIG="${CONFIG_DIR}/frpc.yaml"
readonly CLIENT_STATE="${CONFIG_DIR}/client_state.json"

# Initialize client state file
init_client_state() {
    local state_file="${CLIENT_STATE}"

    if [[ ! -f "${state_file}" ]]; then
        cat > "${state_file}" << 'EOF'
{
  "version": "1.0.0",
  "created": "",
  "last_updated": "",
  "server": {
    "addr": "",
    "port": "",
    "token": "",
    "connected": false
  },
  "tunnels": []
}
EOF
    fi

    # Update timestamps
    local current_time
    current_time=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    if ! jq -e '.created' "${state_file}" >/dev/null 2>&1 || [[ "$(jq -r '.created' "${state_file}")" == "null" ]]; then
        jq --arg time "${current_time}" '.created = $time' "${state_file}" > "${state_file}.tmp" && mv "${state_file}.tmp" "${state_file}"
    fi

    jq --arg time "${current_time}" '.last_updated = $time' "${state_file}" > "${state_file}.tmp" && mv "${state_file}.tmp" "${state_file}"
}

# Update server connection info in state
update_server_state() {
    local server_addr="$1"
    local server_port="$2"
    local token="$3"
    local state_file="${CLIENT_STATE}"

    init_client_state

    jq --arg addr "${server_addr}" \
       --arg port "${server_port}" \
       --arg token "${token}" \
       '.server.addr = $addr | .server.port = $port | .server.token = $token' \
       "${state_file}" > "${state_file}.tmp" && mv "${state_file}.tmp" "${state_file}"

    log_info "Server connection info updated in state"
}

# Create basic client configuration
create_basic_client_config() {
    local server_addr="${1:-127.0.0.1}"
    local server_port="${2:-7000}"
    local token="${3:-}"
    local log_level="${FRP_LOG_LEVEL:-info}"

    log_info "Creating basic client configuration..."

    # Create configuration directory
    mkdir -p "${CONFIG_DIR}"

    # Generate basic client configuration
    cat > "${CLIENT_CONFIG}" << EOF
# FRP Client Configuration - Auto Generated (YAML Format)
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Container: FRP Docker v1.0.0

# Server connection
serverAddr: "${server_addr}"
serverPort: ${server_port}

# Authentication
$(if [[ -n "${token}" ]]; then echo "auth:"; echo "  token: \"${token}\""; fi)

# Logging
log:
  to: "/app/logs/frpc.log"
  level: "${log_level}"
  maxDays: 7

# Transport settings
transport:
  tcpMux: true

# User settings
user: "frpc_user"

# Proxy configurations
proxies: []
EOF

    log_info "Basic client configuration created: ${CLIENT_CONFIG}"
}

# Add tunnel configuration to client config (YAML format)
add_tunnel_to_config() {
    local tunnel_name="$1"
    local local_port="$2"
    local remote_port="$3"
    local protocol="${4:-tcp}"

    log_info "Adding tunnel ${tunnel_name} to configuration..."

    # Create temporary YAML snippet for the new proxy
    local temp_config="/tmp/new_proxy.yaml"
    cat > "${temp_config}" << EOF
- name: "${tunnel_name}"
  type: "${protocol}"
  localIP: "127.0.0.1"
  localPort: ${local_port}
  remotePort: ${remote_port}
  transport:
    useEncryption: false
    useCompression: false
EOF

    # Read current config, add new proxy to proxies array, and write back
    if command -v yq >/dev/null 2>&1; then
        # Use yq if available (more reliable YAML processing)
        yq eval '.proxies += [load("'${temp_config}'")]' -i "${CLIENT_CONFIG}"
    else
        # Fallback: manual YAML manipulation using awk
        # Replace "proxies: []" with the new proxy configuration
        if grep -q "proxies: \[\]" "${CLIENT_CONFIG}"; then
            # First proxy - replace empty array
            awk -v name="${tunnel_name}" -v protocol="${protocol}" -v local_port="${local_port}" -v remote_port="${remote_port}" '
            /proxies: \[\]/ {
                print "proxies:"
                print "- name: \"" name "\""
                print "  type: \"" protocol "\""
                print "  localIP: \"127.0.0.1\""
                print "  localPort: " local_port
                print "  remotePort: " remote_port
                print "  transport:"
                print "    useEncryption: false"
                print "    useCompression: false"
                next
            }
            { print }
            ' "${CLIENT_CONFIG}" > "${CLIENT_CONFIG}.tmp" && mv "${CLIENT_CONFIG}.tmp" "${CLIENT_CONFIG}"
        else
            # Add to existing proxies array - create new proxy entry
            awk -v name="${tunnel_name}" -v protocol="${protocol}" -v local_port="${local_port}" -v remote_port="${remote_port}" '
            /^proxies:/ {
                print
                print "- name: \"" name "\""
                print "  type: \"" protocol "\""
                print "  localIP: \"127.0.0.1\""
                print "  localPort: " local_port
                print "  remotePort: " remote_port
                print "  transport:"
                print "    useEncryption: false"
                print "    useCompression: false"
                next
            }
            { print }
            ' "${CLIENT_CONFIG}" > "${CLIENT_CONFIG}.tmp" && mv "${CLIENT_CONFIG}.tmp" "${CLIENT_CONFIG}"
        fi
    fi

    # Clean up temporary file
    rm -f "${temp_config}"

    log_info "Tunnel ${tunnel_name} added: ${local_port} -> ${remote_port} (${protocol})"
}

# Load tunnels from state and add to config
load_tunnels_from_state() {
    local state_file="${CLIENT_STATE}"

    if [[ ! -f "${state_file}" ]]; then
        return 0
    fi

    local tunnel_count
    tunnel_count=$(jq '.tunnels | length' "${state_file}" 2>/dev/null || echo "0")

    if [[ "${tunnel_count}" -eq 0 ]]; then
        log_info "No tunnels configured"
        return 0
    fi

    log_info "Loading ${tunnel_count} tunnel(s) from state..."

    for ((i=0; i<tunnel_count; i++)); do
        local tunnel
        tunnel=$(jq -r ".tunnels[${i}]" "${state_file}" 2>/dev/null || echo "{}")

        if [[ "${tunnel}" == "{}" ]]; then
            continue
        fi

        local name local_port remote_port protocol
        name=$(echo "${tunnel}" | jq -r '.name // empty')
        local_port=$(echo "${tunnel}" | jq -r '.local_port // empty')
        remote_port=$(echo "${tunnel}" | jq -r '.remote_port // empty')
        protocol=$(echo "${tunnel}" | jq -r '.protocol // "tcp"')

        if [[ -n "${name}" && -n "${local_port}" && -n "${remote_port}" ]]; then
            add_tunnel_to_config "${name}" "${local_port}" "${remote_port}" "${protocol}"
        fi
    done
}

# Initialize client configuration
initialize_client_config() {
    local server_addr="${FRP_SERVER_ADDR:-127.0.0.1}"
    local server_port="${FRP_SERVER_PORT:-7000}"
    local token="${FRP_TOKEN:-}"

    log_info "Initializing FRP client configuration..."

    # Initialize state
    init_client_state

    # Update server info in state if provided
    if [[ -n "${server_addr}" && -n "${server_port}" ]]; then
        update_server_state "${server_addr}" "${server_port}" "${token}"
    fi

    # Create basic configuration
    create_basic_client_config "${server_addr}" "${server_port}" "${token}"

    # Load existing tunnels
    load_tunnels_from_state

    # Validate configuration
    if [[ ! -f "${CLIENT_CONFIG}" ]]; then
        error_exit "Failed to create client configuration"
    fi

    log_info "Client configuration initialized successfully"

    # Show connection info
    echo ""
    echo "=========================================="
    echo "   FRP CLIENT CONFIGURATION READY"
    echo "=========================================="
    echo ""
    echo "📡 Server: ${server_addr}:${server_port}"
    if [[ -n "${token}" ]]; then
        echo "🔑 Token: ${token:0:8}..."
    else
        echo "⚠️  No authentication token configured"
    fi
    echo "📁 Config: ${CLIENT_CONFIG}"
    echo "📊 State: ${CLIENT_STATE}"
    echo ""
    echo "💡 To add tunnels, use: docker exec -it CONTAINER shell"
    echo "=========================================="
    echo ""
}

# Health check function
check_client_health() {
    local config_file="${CLIENT_CONFIG}"

    if [[ ! -f "${config_file}" ]]; then
        echo "Client configuration missing"
        return 1
    fi

    if [[ ! -s "${config_file}" ]]; then
        echo "Client configuration is empty"
        return 1
    fi

    # Check if server info is configured (YAML format)
    if ! grep -q "serverAddr" "${config_file}"; then
        echo "Server address not configured"
        return 1
    fi

    echo "Client configuration OK"
    return 0
}

# Reload client configuration (for use by CLI)
reload_client_config() {
    local state_file="${CLIENT_STATE}"

    if [[ ! -f "${state_file}" ]]; then
        error_exit "Client state file not found: ${state_file}"
    fi

    # Extract server info from state
    local server_addr server_port token
    server_addr=$(jq -r '.server.addr // "127.0.0.1"' "${state_file}")
    server_port=$(jq -r '.server.port // "7000"' "${state_file}")
    token=$(jq -r '.server.token // ""' "${state_file}")

    log_info "Reloading client configuration from state..."

    # Recreate configuration
    create_basic_client_config "${server_addr}" "${server_port}" "${token}"
    load_tunnels_from_state

    log_info "Client configuration reloaded successfully"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-init}" in
        "init")
            initialize_client_config
            ;;
        "reload")
            reload_client_config
            ;;
        "health"|"check")
            check_client_health
            ;;
        *)
            echo "Usage: $0 {init|reload|health}"
            exit 1
            ;;
    esac
fi