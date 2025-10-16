#!/bin/bash
##
## FRP Docker Health Check - Enterprise Grade
## Comprehensive health monitoring for both client and server modes
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Global variables
readonly FRP_DIR="/app/frp"
readonly CONFIG_DIR="/app/configs"
readonly LOG_DIR="/app/logs"

# Health check for server mode
check_server_health() {
    local config_file="${CONFIG_DIR}/frps.yaml"
    local auth_file="${CONFIG_DIR}/server_auth.txt"
    local binary="${FRP_DIR}/frps"
    local log_file="${LOG_DIR}/frps.log"

    # Check if configuration exists
    if [[ ! -f "$config_file" ]]; then
        echo "Server config missing"
        exit 1
    fi

    # Check if auth file exists
    if [[ ! -f "$auth_file" ]]; then
        echo "Server auth file missing"
        exit 1
    fi

    # Check if binary exists and is executable
    if [[ ! -x "$binary" ]]; then
        echo "Server binary missing or not executable"
        exit 1
    fi

    # Check if process might be running by looking for recent log activity
    if [[ -f "$log_file" ]]; then
        # Check if log has been written to recently (within last 5 minutes)
        if find "$log_file" -mmin -5 | grep -q .; then
            echo "Server health OK"
            exit 0
        fi
    fi

    # If we reach here, do a basic syntax check of the config (YAML format)
    if grep -q "bindPort" "$config_file" && grep -q "token" "$config_file"; then
        echo "Server health OK"
        exit 0
    fi

    echo "Server health check failed"
    exit 1
}

# Health check for client mode
check_client_health() {
    local config_file="${CONFIG_DIR}/frpc.yaml"
    local state_file="${CONFIG_DIR}/client_state.json"
    local binary="${FRP_DIR}/frpc"
    local log_file="${LOG_DIR}/frpc.log"

    # Check if configuration exists
    if [[ ! -f "$config_file" ]]; then
        echo "Client config missing"
        exit 1
    fi

    # Check if binary exists and is executable
    if [[ ! -x "$binary" ]]; then
        echo "Client binary missing or not executable"
        exit 1
    fi

    # Check if state file exists (created by CLI)
    if [[ ! -f "$state_file" ]]; then
        # State file is optional, but config must have serverAddr (YAML format)
        if ! grep -q "serverAddr" "$config_file"; then
            echo "Client server address not configured"
            exit 1
        fi
    else
        # Validate state file structure
        if ! jq -e '.server.addr' "$state_file" >/dev/null 2>&1; then
            echo "Client state file corrupted"
            exit 1
        fi
    fi

    # Check if log exists and has recent activity
    if [[ -f "$log_file" ]]; then
        # Check if log has been written to recently (within last 5 minutes)
        if find "$log_file" -mmin -5 | grep -q .; then
            echo "Client health OK"
            exit 0
        fi
    fi

    # Basic config validation (YAML format)
    if grep -q "serverAddr" "$config_file" && grep -q "serverPort" "$config_file"; then
        echo "Client health OK"
        exit 0
    fi

    echo "Client health check failed"
    exit 1
}

# Main health check logic
main() {
    case "${FRP_MODE:-client}" in
        "server")
            check_server_health
            ;;
        "client")
            check_client_health
            ;;
        *)
            echo "Invalid FRP_MODE: ${FRP_MODE:-client}"
            exit 1
            ;;
    esac
}

# Execute health check
main "$@"