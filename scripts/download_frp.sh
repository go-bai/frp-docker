#!/bin/bash
##
## FRP Binary Download Manager - Enterprise Grade
## Automatically downloads latest FRP binaries with verification
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
if [[ -z "${FRP_DIR:-}" ]]; then
    readonly FRP_DIR="/app/frp"
fi
readonly CACHE_DIR="/tmp/frp_cache"
readonly GITHUB_API_URL="https://api.github.com/repos/fatedier/frp/releases"
readonly USER_AGENT="FRP-Docker/1.0.0"

# Create necessary directories
mkdir -p "${FRP_DIR}" "${CACHE_DIR}"

# Check if FRP is already installed and current
is_frp_current() {
    local current_version
    local latest_version

    # Check if binaries exist
    if [[ ! -f "${FRP_DIR}/frps" ]] || [[ ! -f "${FRP_DIR}/frpc" ]]; then
        log_info "FRP binaries not found, need to download"
        return 1
    fi

    # Get current version if version file exists
    if [[ -f "${FRP_DIR}/VERSION" ]]; then
        current_version=$(cat "${FRP_DIR}/VERSION" 2>/dev/null || echo "unknown")
    else
        log_info "Version file not found, assuming outdated installation"
        return 1
    fi

    # If FRP_VERSION is specified and not "latest", check exact match
    if [[ "${FRP_VERSION:-latest}" != "latest" ]]; then
        if [[ "${current_version}" == "${FRP_VERSION}" ]]; then
            log_info "FRP version ${current_version} matches requested version"
            return 0
        else
            log_info "Current version ${current_version} != requested ${FRP_VERSION}"
            return 1
        fi
    fi

    # For "latest", check against GitHub
    latest_version=$(get_latest_version)
    if [[ "${current_version}" == "${latest_version}" ]]; then
        log_info "FRP is already at latest version: ${current_version}"
        return 0
    else
        log_info "Update available: ${current_version} -> ${latest_version}"
        return 1
    fi
}

# Get latest version from GitHub API
get_latest_version() {
    local version

    log_info "Fetching latest FRP version from GitHub API..." >&2

    # Try with curl first
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -fsSL \
            -H "User-Agent: ${USER_AGENT}" \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API_URL}/latest" 2>/dev/null | \
            jq -r '.tag_name // empty' 2>/dev/null || echo "")
    fi

    # Fallback to wget if curl failed
    if [[ -z "${version:-}" ]] && command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- \
            --header="User-Agent: ${USER_AGENT}" \
            --header="Accept: application/vnd.github.v3+json" \
            "${GITHUB_API_URL}/latest" 2>/dev/null | \
            jq -r '.tag_name // empty' 2>/dev/null || echo "")
    fi

    if [[ -z "${version:-}" ]]; then
        log_warn "Failed to fetch version from API, using fallback method..." >&2
        # Fallback: try to scrape releases page (BusyBox grep compatible)
        version=$(curl -fsSL "https://github.com/fatedier/frp/releases/latest" 2>/dev/null | \
            grep -o 'tag/v*[0-9]*\.[0-9]*\.[0-9]*' | \
            sed 's|tag/v*||' | head -1 || echo "")

        if [[ -n "${version}" ]]; then
            version="v${version}"
        fi
    fi

    if [[ -z "${version:-}" ]]; then
        error_exit "Failed to determine latest FRP version"
    fi

    echo "${version}"
}

# Get specific version or latest
get_target_version() {
    if [[ "${FRP_VERSION:-latest}" == "latest" ]]; then
        get_latest_version
    else
        # Ensure version starts with 'v'
        local version="${FRP_VERSION}"
        if [[ ! "${version}" =~ ^v ]]; then
            version="v${version}"
        fi
        echo "${version}"
    fi
}

# Download and extract FRP binary
download_frp_archive() {
    local version="$1"
    local arch="$2"
    local download_url
    local archive_name
    local temp_archive

    archive_name="frp_${version#v}_linux_${arch}.tar.gz"
    download_url="https://github.com/fatedier/frp/releases/download/${version}/${archive_name}"
    temp_archive="${CACHE_DIR}/${archive_name}"

    log_info "Downloading FRP ${version} for ${arch}..."
    log_info "URL: ${download_url}"

    # Download with progress and retry logic
    local attempt=1
    local max_attempts=3

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Download attempt ${attempt}/${max_attempts}..."

        if curl -fSL \
            -H "User-Agent: ${USER_AGENT}" \
            --connect-timeout 30 \
            --max-time 300 \
            --retry 2 \
            --retry-delay 5 \
            -o "${temp_archive}" \
            "${download_url}"; then
            log_info "Download completed successfully"
            break
        else
            if [[ ${attempt} -eq ${max_attempts} ]]; then
                error_exit "Failed to download FRP archive after ${max_attempts} attempts"
            fi
            log_warn "Download attempt ${attempt} failed, retrying..."
            ((attempt++))
            sleep 5
        fi
    done

    # Verify download
    if [[ ! -f "${temp_archive}" ]] || [[ ! -s "${temp_archive}" ]]; then
        error_exit "Downloaded archive is missing or empty"
    fi

    log_info "Archive downloaded successfully: $(du -h "${temp_archive}" | cut -f1)"

    # Extract archive
    log_info "Extracting archive..."
    local extract_dir="${CACHE_DIR}/extract"
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"

    if ! tar -xzf "${temp_archive}" -C "${extract_dir}"; then
        error_exit "Failed to extract archive"
    fi

    # Find and copy binaries
    local frp_folder
    frp_folder=$(find "${extract_dir}" -name "frp_*" -type d | head -1)

    if [[ -z "${frp_folder}" ]]; then
        error_exit "FRP folder not found in extracted archive"
    fi

    log_info "Installing binaries from: ${frp_folder}"

    # Copy binaries
    for binary in frps frpc; do
        local src="${frp_folder}/${binary}"
        local dest="${FRP_DIR}/${binary}"

        if [[ ! -f "${src}" ]]; then
            error_exit "Binary not found: ${src}"
        fi

        cp "${src}" "${dest}"
        chmod +x "${dest}"
        log_info "Installed: ${binary}"
    done

    # Save version info
    echo "${version}" > "${FRP_DIR}/VERSION"

    # Save additional info
    cat > "${FRP_DIR}/INFO" << EOF
Version: ${version}
Architecture: ${arch}
Downloaded: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Source: ${download_url}
EOF

    # Cleanup
    rm -rf "${temp_archive}" "${extract_dir}"

    log_info "FRP ${version} installation completed successfully"
}

# Verify binary integrity
verify_binaries() {
    local version="$1"

    log_info "Verifying FRP binaries..."

    for binary in frps frpc; do
        local binary_path="${FRP_DIR}/${binary}"

        if [[ ! -f "${binary_path}" ]]; then
            error_exit "Binary missing: ${binary_path}"
        fi

        if [[ ! -x "${binary_path}" ]]; then
            error_exit "Binary not executable: ${binary_path}"
        fi

        # Test binary execution
        if ! timeout 5 "${binary_path}" --version >/dev/null 2>&1; then
            log_warn "Binary test failed for ${binary}, but continuing..."
        fi
    done

    log_info "Binary verification completed"
}

# Main download function
download_frp_binary() {
    local target_version
    local arch="${FRP_ARCH:-$(uname -m)}"

    # Normalize architecture (handle both raw and already-normalized values)
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) error_exit "Unsupported architecture: $arch" ;;
    esac

    log_info "Starting FRP binary management..."
    log_info "Target architecture: ${arch}"
    log_info "Requested version: ${FRP_VERSION:-latest}"

    # Check if current installation is sufficient
    if is_frp_current; then
        log_info "FRP is already up to date, skipping download"
        verify_binaries "$(cat "${FRP_DIR}/VERSION" 2>/dev/null || echo "unknown")"
        return 0
    fi

    # Get target version
    target_version=$(get_target_version)
    log_info "Target version: ${target_version}"

    # Download and install
    download_frp_archive "${target_version}" "${arch}"
    verify_binaries "${target_version}"

    log_info "FRP binary management completed successfully"
}

# Execute if called directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_frp_binary "$@"
fi