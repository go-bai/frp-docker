#!/bin/bash
##
## FRP Client CLI - Enterprise Grade Interactive Shell
## Advanced tunnel management with Linus-level code quality
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Color definitions for beautiful output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global configuration
readonly CONFIG_DIR="/app/configs"
readonly CLIENT_STATE="${CONFIG_DIR}/client_state.json"
readonly CLIENT_CONFIG="${CONFIG_DIR}/frpc.yaml"
readonly SCRIPT_DIR="/app/scripts"

# Logging functions with colors
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*" >&2
}

# Print colored header
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                          FRP CLIENT CLI - ENTERPRISE GRADE                                           ║"
    echo "║                                     Advanced Tunnel Management System                                                 ║"
    echo "║                                        Built with Linus-level Quality                                                 ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print command help - simplified
print_help() {
    echo -e "${WHITE}FRP Client CLI Commands:${NC}"
    echo ""
    echo -e "${CYAN}Essential Commands:${NC}"
    echo -e "  ${GREEN}status${NC}            - Show connection and tunnel status"
    echo -e "  ${GREEN}add${NC}               - Add new tunnel (interactive)"
    echo -e "  ${GREEN}add <name> <local> <remote> [protocol]${NC} - Add tunnel with parameters"
    echo -e "  ${GREEN}list${NC}              - List all configured tunnels"
    echo -e "  ${GREEN}remove <name>${NC}     - Remove tunnel by name"
    echo ""
    echo -e "${CYAN}General:${NC}"
    echo -e "  ${GREEN}help${NC}              - Show this help message"
    echo -e "  ${GREEN}exit${NC} | ${GREEN}quit${NC}        - Exit CLI"
    echo ""
}

# Initialize state file if needed
init_state() {
    if [[ ! -f "${CLIENT_STATE}" ]]; then
        cat > "${CLIENT_STATE}" << 'EOF'
{
  "version": "1.0.0",
  "created": "",
  "last_updated": "",
  "server": {
    "addr": "",
    "port": "7000",
    "token": "",
    "connected": false
  },
  "tunnels": []
}
EOF
    fi

    # Update timestamp
    local current_time
    current_time=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    jq --arg time "${current_time}" '.last_updated = $time' "${CLIENT_STATE}" > "${CLIENT_STATE}.tmp" && mv "${CLIENT_STATE}.tmp" "${CLIENT_STATE}"
}

# Validate input with regex patterns - fixed for Alpine Linux
validate_input() {
    local input_type="$1"
    local input_value="$2"

    case "$input_type" in
        "ip")
            # Check if it's an IP or hostname
            if [[ "$input_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$input_value" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "port")
            # Check if it's a number between 1-65535
            if [[ "$input_value" =~ ^[0-9]+$ ]] && [[ "$input_value" -ge 1 ]] && [[ "$input_value" -le 65535 ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "name")
            # Check alphanumeric with dashes and underscores, 1-50 chars
            if [[ "$input_value" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#input_value} -ge 1 ]] && [[ ${#input_value} -le 50 ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "protocol")
            # Check if it's a valid protocol
            case "$input_value" in
                "tcp"|"udp"|"http"|"https")
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
    esac
    return 1
}

# Simplified read without complex validation loop - for better interactivity
simple_read() {
    local prompt="$1"
    local default_value="${2:-}"
    local result

    if [[ -n "$default_value" ]]; then
        echo -ne "${CYAN}${prompt} (${default_value}): ${NC}" >&2
    else
        echo -ne "${CYAN}${prompt}: ${NC}" >&2
    fi

    read -r result

    if [[ -z "$result" && -n "$default_value" ]]; then
        result="$default_value"
    fi

    echo "$result"
}

# Add tunnel command - simplified interactive input
cmd_add_tunnel() {
    local name="${1:-}"
    local local_port="${2:-}"
    local remote_port="${3:-}"
    local protocol="${4:-tcp}"

    # Interactive mode if no parameters
    if [[ -z "$name" ]]; then
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                                             ADD NEW TUNNEL                                                          ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Use simplified read and validate afterwards
        name=$(simple_read "Tunnel Name")
        local_port=$(simple_read "Local Port")
        remote_port=$(simple_read "Remote Port")
        protocol=$(simple_read "Protocol" "tcp")
    fi

    # Validate all parameters after input
    if ! validate_input "name" "$name"; then
        log_error "Invalid tunnel name: '$name'. Use only letters, numbers, dash and underscore (1-50 chars)"
        return 1
    fi

    if ! validate_input "port" "$local_port"; then
        log_error "Invalid local port: '$local_port'. Must be between 1-65535"
        return 1
    fi

    if ! validate_input "port" "$remote_port"; then
        log_error "Invalid remote port: '$remote_port'. Must be between 1-65535"
        return 1
    fi

    if ! validate_input "protocol" "$protocol"; then
        log_error "Invalid protocol: '$protocol'. Must be tcp, udp, http or https"
        return 1
    fi

    # Check if tunnel name already exists
    local existing_tunnels
    existing_tunnels=$(jq -r '.tunnels[].name' "${CLIENT_STATE}" 2>/dev/null || echo "")

    if echo "$existing_tunnels" | grep -qx "$name"; then
        log_error "Tunnel '$name' already exists"
        return 1
    fi

    # Add tunnel to state
    jq --arg name "$name" \
       --arg local_port "$local_port" \
       --arg remote_port "$remote_port" \
       --arg protocol "$protocol" \
       --arg created "$(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
       '.tunnels += [{
           "name": $name,
           "local_port": $local_port,
           "remote_port": $remote_port,
           "protocol": $protocol,
           "enabled": true,
           "created": $created
       }]' \
       "${CLIENT_STATE}" > "${CLIENT_STATE}.tmp" && mv "${CLIENT_STATE}.tmp" "${CLIENT_STATE}"

    # Regenerate configuration
    if [[ -f "${SCRIPT_DIR}/client_init.sh" ]]; then
        bash "${SCRIPT_DIR}/client_init.sh" reload
        log_success "Tunnel '$name' added successfully!"
        echo ""
        echo -e "${GREEN}✓ Name: $name${NC}"
        echo -e "${GREEN}✓ Local Port: $local_port${NC}"
        echo -e "${GREEN}✓ Remote Port: $remote_port${NC}"
        echo -e "${GREEN}✓ Protocol: $protocol${NC}"
        echo ""
    else
        log_error "Failed to update configuration"
        return 1
    fi
}

# Remove tunnel command
cmd_remove_tunnel() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        log_error "Usage: remove <tunnel_name>"
        return 1
    fi

    # Check if tunnel exists
    local tunnel_index
    tunnel_index=$(jq -r --arg name "$name" '.tunnels | to_entries | .[] | select(.value.name == $name) | .key' "${CLIENT_STATE}" 2>/dev/null | head -1)

    if [[ -z "$tunnel_index" ]]; then
        log_error "Tunnel '$name' not found"
        return 1
    fi

    # Remove tunnel from state
    jq --argjson index "$tunnel_index" 'del(.tunnels[$index])' "${CLIENT_STATE}" > "${CLIENT_STATE}.tmp" && mv "${CLIENT_STATE}.tmp" "${CLIENT_STATE}"

    # Regenerate configuration
    if [[ -f "${SCRIPT_DIR}/client_init.sh" ]]; then
        bash "${SCRIPT_DIR}/client_init.sh" reload
        log_success "Tunnel '$name' removed successfully!"
    else
        log_error "Failed to update configuration"
        return 1
    fi
}

# List tunnels command
cmd_list_tunnels() {
    local tunnel_count
    tunnel_count=$(jq '.tunnels | length' "${CLIENT_STATE}" 2>/dev/null || echo "0")

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                           CONFIGURED TUNNELS                                                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$tunnel_count" -eq 0 ]]; then
        echo -e "${YELLOW}No tunnels configured${NC}"
        echo ""
        return 0
    fi

    printf "%-20s %-10s %-12s %-12s %-10s %-20s\n" "NAME" "PROTOCOL" "LOCAL PORT" "REMOTE PORT" "STATUS" "CREATED"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

    for ((i=0; i<tunnel_count; i++)); do
        local tunnel
        tunnel=$(jq -r ".tunnels[$i]" "${CLIENT_STATE}" 2>/dev/null || echo "{}")

        if [[ "$tunnel" == "{}" ]]; then
            continue
        fi

        local name protocol local_port remote_port enabled created status_text
        name=$(echo "$tunnel" | jq -r '.name // "N/A"')
        protocol=$(echo "$tunnel" | jq -r '.protocol // "tcp"')
        local_port=$(echo "$tunnel" | jq -r '.local_port // "N/A"')
        remote_port=$(echo "$tunnel" | jq -r '.remote_port // "N/A"')
        enabled=$(echo "$tunnel" | jq -r '.enabled // true')
        created=$(echo "$tunnel" | jq -r '.created // "Unknown"')

        if [[ "$enabled" == "true" ]]; then
            status_text="ENABLED"
        else
            status_text="DISABLED"
        fi

        # Print row with colors applied correctly
        printf "%-20s %-10s %-12s %-12s " "$name" "$protocol" "$local_port" "$remote_port"
        if [[ "$enabled" == "true" ]]; then
            echo -e "${GREEN}ENABLED${NC}    ${created:0:16}"
        else
            echo -e "${RED}DISABLED${NC}   ${created:0:16}"
        fi
    done

    echo ""
}

# Show status command
cmd_status() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                              CLIENT STATUS                                                           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Server connection info
    local server_addr server_port token connected tunnel_count
    server_addr=$(jq -r '.server.addr // "Not configured"' "${CLIENT_STATE}")
    server_port=$(jq -r '.server.port // "7000"' "${CLIENT_STATE}")
    token=$(jq -r '.server.token // ""' "${CLIENT_STATE}")
    connected=$(jq -r '.server.connected // false' "${CLIENT_STATE}")
    tunnel_count=$(jq '.tunnels | length' "${CLIENT_STATE}" 2>/dev/null || echo "0")

    echo -e "${WHITE}Server Connection:${NC}"
    echo -e "  Server: $server_addr:$server_port"

    if [[ -n "$token" ]]; then
        echo -e "  Token: ${token:0:8}***"
    else
        echo -e "  Token: ${RED}Not configured${NC}"
    fi

    if [[ "$connected" == "true" ]]; then
        echo -e "  Status: ${GREEN}Connected${NC}"
    else
        echo -e "  Status: ${YELLOW}Disconnected${NC}"
    fi

    echo ""
    echo -e "${WHITE}Tunnels:${NC}"
    echo -e "  Count: $tunnel_count"

    # Configuration files
    echo ""
    echo -e "${WHITE}Configuration:${NC}"
    echo -e "  Config: $CLIENT_CONFIG"
    echo -e "  State: $CLIENT_STATE"

    if [[ -f "$CLIENT_CONFIG" ]]; then
        echo -e "  Config Status: ${GREEN}OK${NC}"
    else
        echo -e "  Config Status: ${RED}Missing${NC}"
    fi

    echo ""
}

# Main CLI loop - simplified
run_cli() {
    # Initialize
    init_state
    print_header

    echo -e "${GREEN}Welcome to FRP Client CLI!${NC}"
    echo -e "${CYAN}Type 'help' for available commands${NC}"
    echo ""

    while true; do
        echo -ne "${PURPLE}frp-cli${NC} ${CYAN}>${NC} "
        read -r -a input

        if [[ ${#input[@]} -eq 0 ]]; then
            continue
        fi

        local command="${input[0]}"
        local args=("${input[@]:1}")

        case "$command" in
            "help"|"h"|"?")
                print_help
                ;;
            "status"|"stat")
                cmd_status
                ;;
            "add")
                cmd_add_tunnel "${args[@]}"
                ;;
            "remove"|"rm"|"delete")
                cmd_remove_tunnel "${args[0]:-}"
                ;;
            "list"|"ls")
                cmd_list_tunnels
                ;;
            "exit"|"quit"|"q")
                echo -e "${GREEN}Goodbye!${NC}"
                break
                ;;
            "clear"|"cls")
                clear
                print_header
                ;;
            "")
                continue
                ;;
            *)
                log_error "Unknown command: $command"
                echo -e "${CYAN}Type 'help' for available commands${NC}"
                ;;
        esac
    done
}

# Execute CLI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_cli "$@"
fi