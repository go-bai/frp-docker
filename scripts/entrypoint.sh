#!/bin/bash
##
## FRP Docker Entrypoint - Enterprise Grade Implementation
## Intelligent mode detection and binary management
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Color output functions for better UX
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&1
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [[ "${FRP_LOG_LEVEL:-info}" == "debug" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Trap errors
trap 'error_exit "Script failed at line $LINENO"' ERR

# Global variables
readonly SCRIPT_DIR="/app/scripts"
readonly CONFIG_DIR="/app/configs"
readonly FRP_DIR="/app/frp"
readonly LOG_DIR="/app/logs"

# Architecture detection
detect_architecture() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            error_exit "Unsupported architecture: $arch"
            ;;
    esac
}

# Validate environment
validate_environment() {
    log_info "Validating environment configuration..."

    # Validate FRP_MODE
    case "${FRP_MODE:-client}" in
        client|server)
            log_info "FRP mode set to: ${FRP_MODE}"
            ;;
        *)
            error_exit "Invalid FRP_MODE: ${FRP_MODE}. Must be 'client' or 'server'"
            ;;
    esac

    # Set architecture if not provided
    if [[ -z "${FRP_ARCH:-}" ]]; then
        export FRP_ARCH
        FRP_ARCH=$(detect_architecture)
        log_info "Auto-detected architecture: ${FRP_ARCH}"
    fi

    # Validate ports
    if [[ ! "${FRP_SERVER_PORT:-7000}" =~ ^[0-9]+$ ]] || \
       [[ "${FRP_SERVER_PORT:-7000}" -lt 1 ]] || \
       [[ "${FRP_SERVER_PORT:-7000}" -gt 65535 ]]; then
        error_exit "Invalid FRP_SERVER_PORT: ${FRP_SERVER_PORT:-7000}"
    fi

    log_info "Environment validation completed successfully"
}

# Download and setup FRP binary
setup_frp_binary() {
    log_info "Checking FRP binary..."

    # Check if binaries already exist (pre-installed in image)
    if [[ -f "${FRP_DIR}/frps" ]] && [[ -f "${FRP_DIR}/frpc" ]]; then
        log_info "FRP binaries found in image"

        # Verify binaries are executable
        if [[ -x "${FRP_DIR}/frps" ]] && [[ -x "${FRP_DIR}/frpc" ]]; then
            local version="unknown"
            if [[ -f "${FRP_DIR}/VERSION" ]]; then
                version=$(cat "${FRP_DIR}/VERSION")
            fi
            log_info "Using pre-installed FRP version: ${version}"
            return 0
        else
            log_warn "Binaries found but not executable, fixing permissions..."
            chmod +x "${FRP_DIR}/frps" "${FRP_DIR}/frpc"
            return 0
        fi
    fi

    # Binaries not found, try to download (fallback for compatibility)
    log_warn "FRP binaries not found in image, attempting runtime download..."

    # Source the download script
    if [[ -f "${SCRIPT_DIR}/download_frp.sh" ]]; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/download_frp.sh"
        download_frp_binary
    else
        error_exit "FRP binaries not found and download script unavailable"
    fi
}

# Initialize configuration
initialize_config() {
    log_info "Initializing configuration for ${FRP_MODE} mode..."

    case "${FRP_MODE}" in
        server)
            if [[ -f "${SCRIPT_DIR}/server_init.sh" ]]; then
                # shellcheck source=/dev/null
                source "${SCRIPT_DIR}/server_init.sh"
                initialize_server_config
            else
                error_exit "Server initialization script not found"
            fi
            ;;
        client)
            if [[ -f "${SCRIPT_DIR}/client_init.sh" ]]; then
                # shellcheck source=/dev/null
                source "${SCRIPT_DIR}/client_init.sh"
                initialize_client_config
            else
                error_exit "Client initialization script not found"
            fi
            ;;
    esac
}

# Setup supervisord for client mode
setup_supervisord_client() {
    log_info "Setting up supervisord for client mode..."

    # Copy supervisord main config (overwrite the default one)
    if [[ -f "${CONFIG_DIR}/supervisord.conf" ]]; then
        cp -f "${CONFIG_DIR}/supervisord.conf" /etc/supervisord.conf
        log_info "Supervisord main config copied"
    else
        error_exit "Supervisord config not found: ${CONFIG_DIR}/supervisord.conf"
    fi

    # Copy frpc supervisor config
    if [[ -f "${CONFIG_DIR}/frpc.conf" ]]; then
        cp -f "${CONFIG_DIR}/frpc.conf" /etc/supervisor/conf.d/frpc.conf
        log_info "FRPC supervisor config copied"
    else
        error_exit "FRPC supervisor config not found: ${CONFIG_DIR}/frpc.conf"
    fi

    # Copy sshd supervisor config (autostart=false by default)
    if [[ -f "${CONFIG_DIR}/sshd.conf" ]]; then
        cp -f "${CONFIG_DIR}/sshd.conf" /etc/supervisor/conf.d/sshd.conf
        log_info "SSHD supervisor config copied (autostart=false)"
    else
        log_warn "SSHD supervisor config not found, skipping"
    fi

    # Generate SSH host keys if not exists
    if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
        log_info "Generating SSH host keys..."
        ssh-keygen -A
    fi

    log_info "Supervisord setup completed for client mode"
}

# Setup supervisord for server mode
setup_supervisord_server() {
    log_info "Setting up supervisord for server mode..."

    # Copy supervisord main config (overwrite the default one)
    if [[ -f "${CONFIG_DIR}/supervisord.conf" ]]; then
        cp -f "${CONFIG_DIR}/supervisord.conf" /etc/supervisord.conf
        log_info "Supervisord main config copied"
    else
        error_exit "Supervisord config not found: ${CONFIG_DIR}/supervisord.conf"
    fi

    # Copy frps supervisor config
    if [[ -f "${CONFIG_DIR}/frps.conf" ]]; then
        cp -f "${CONFIG_DIR}/frps.conf" /etc/supervisor/conf.d/frps.conf
        log_info "FRPS supervisor config copied"
    else
        error_exit "FRPS supervisor config not found: ${CONFIG_DIR}/frps.conf"
    fi

    log_info "Supervisord setup completed for server mode"
}

# Start FRP service
start_frp_service() {
    local config_file
    local binary_name

    case "${FRP_MODE}" in
        server)
            binary_name="frps"
            config_file="${CONFIG_DIR}/frps.yaml"

            local binary_path="${FRP_DIR}/${binary_name}"

            if [[ ! -f "${binary_path}" ]]; then
                error_exit "FRP binary not found: ${binary_path}"
            fi

            if [[ ! -f "${config_file}" ]]; then
                error_exit "Configuration file not found: ${config_file}"
            fi

            # Make binary executable
            chmod +x "${binary_path}"

            log_info "Starting FRP server with supervisord..."
            log_info "Binary: ${binary_path}"
            log_info "Config: ${config_file}"

            # Setup and start supervisord
            setup_supervisord_server

            # Start supervisord as PID 1
            log_info "Starting supervisord as PID 1..."
            exec /usr/bin/supervisord -c /etc/supervisord.conf
            ;;
        client)
            binary_name="frpc"
            config_file="${CONFIG_DIR}/frpc.yaml"

            local binary_path="${FRP_DIR}/${binary_name}"

            if [[ ! -f "${binary_path}" ]]; then
                error_exit "FRP binary not found: ${binary_path}"
            fi

            if [[ ! -f "${config_file}" ]]; then
                error_exit "Configuration file not found: ${config_file}"
            fi

            # Make binary executable
            chmod +x "${binary_path}"

            log_info "Starting FRP client with supervisord..."
            log_info "Binary: ${binary_path}"
            log_info "Config: ${config_file}"

            # Setup and start supervisord
            setup_supervisord_client

            # Start supervisord as PID 1
            log_info "Starting supervisord as PID 1..."
            exec /usr/bin/supervisord -c /etc/supervisord.conf
            ;;
    esac
}

# Handle special commands
handle_special_commands() {
    case "${1:-}" in
        "shell"|"cli")
            if [[ "${FRP_MODE}" == "client" ]]; then
                log_info "Starting FRP client CLI..."
                exec "${SCRIPT_DIR}/frp_cli.sh"
            else
                error_exit "CLI mode only available in client mode"
            fi
            ;;
        "version")
            if [[ -f "${FRP_DIR}/frps" ]]; then
                exec "${FRP_DIR}/frps" --version
            elif [[ -f "${FRP_DIR}/frpc" ]]; then
                exec "${FRP_DIR}/frpc" --version
            else
                echo "FRP binaries not found. Please run container without commands to download them first."
                exit 1
            fi
            ;;
        "help")
            cat << 'EOF'
FRP Docker Container - Usage

Environment Variables:
  FRP_MODE        - Mode: client or server (default: client)
  FRP_VERSION     - FRP version to download (default: latest)
  FRP_SERVER_PORT - Server port (default: 7000)
  FRP_WEB_PORT    - Web dashboard port (default: 7500)
  FRP_LOG_LEVEL   - Log level: debug, info, warn, error (default: info)
  FRP_ARCH        - Architecture: amd64, arm64 (auto-detected)

Commands:
  (none)          - Start FRP service
  shell|cli       - Start interactive CLI (client mode only)
  version         - Show FRP version
  help            - Show this help message

Examples:
  # Start FRP server
  docker run -e FRP_MODE=server --network host frp-docker

  # Start FRP client with CLI
  docker run -it -e FRP_MODE=client frp-docker shell

  # Start FRP client with shared network namespace
  docker run --network container:other-container frp-docker
EOF
            exit 0
            ;;
    esac
}

# Main execution flow
main() {
    log_info "Starting FRP Docker Container v1.0.0"
    log_info "Architecture: $(uname -m), OS: $(uname -s)"

    # Handle special commands first
    if [[ $# -gt 0 ]]; then
        handle_special_commands "$@"
    fi

    # Standard startup flow
    validate_environment
    setup_frp_binary
    initialize_config
    start_frp_service
}

# Execute main function with all arguments
main "$@"