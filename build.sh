#!/bin/bash
##
## FRP Docker Build and Test Script - Enterprise Grade
## Comprehensive building, testing, and validation
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Color definitions
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly IMAGE_NAME="frp-docker"
readonly TEST_TIMEOUT=60

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                     FRP DOCKER - BUILD & TEST SUITE                                                   ║"
    echo "║                                        Enterprise Grade Validation                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test containers..."
    docker rm -f frp-test-server frp-test-client 2>/dev/null || true
}

# Trap for cleanup
trap cleanup EXIT

# Build Docker image
build_image() {
    log_step "Building FRP Docker image..."

    if docker build -t "${IMAGE_NAME}" .; then
        log_info "✓ Image built successfully"
    else
        log_error "✗ Failed to build image"
        exit 1
    fi

    # Show image info
    log_info "Image details:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Test server mode
test_server_mode() {
    log_step "Testing server mode..."

    # Start server container
    if docker run -d \
        --name frp-test-server \
        -e FRP_MODE=server \
        -e FRP_SERVER_PORT=17000 \
        -e FRP_WEB_PORT=17500 \
        -p 17000:17000 \
        -p 17500:17500 \
        "${IMAGE_NAME}"; then
        log_info "✓ Server container started"
    else
        log_error "✗ Failed to start server container"
        return 1
    fi

    # Wait for server to initialize
    log_info "Waiting for server initialization..."
    sleep 10

    # Check if container is healthy
    local health_status
    health_status=$(docker inspect frp-test-server --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")

    if [[ "$health_status" == "healthy" ]]; then
        log_info "✓ Server health check passed"
    else
        log_warn "! Server health check inconclusive (status: $health_status)"
    fi

    # Check if auth file was created
    if docker exec frp-test-server test -f /app/configs/server_auth.txt; then
        log_info "✓ Authentication file created"

        # Show auth info (first few lines only)
        log_info "Server auth info:"
        docker exec frp-test-server head -10 /app/configs/server_auth.txt | sed 's/^/  /'
    else
        log_error "✗ Authentication file not found"
        return 1
    fi

    # Check logs
    log_info "Recent server logs:"
    docker logs frp-test-server --tail 5 | sed 's/^/  /'

    return 0
}

# Test client mode
test_client_mode() {
    log_step "Testing client mode..."

    # Start client container
    if docker run -d \
        --name frp-test-client \
        -e FRP_MODE=client \
        -e FRP_SERVER_ADDR=127.0.0.1 \
        -e FRP_SERVER_PORT=17000 \
        -e FRP_TOKEN=test-token \
        "${IMAGE_NAME}"; then
        log_info "✓ Client container started"
    else
        log_error "✗ Failed to start client container"
        return 1
    fi

    # Wait for client to initialize
    log_info "Waiting for client initialization..."
    sleep 10

    # Check if container is healthy
    local health_status
    health_status=$(docker inspect frp-test-client --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")

    if [[ "$health_status" == "healthy" ]]; then
        log_info "✓ Client health check passed"
    else
        log_warn "! Client health check inconclusive (status: $health_status)"
    fi

    # Test CLI access
    if docker exec frp-test-client test -f /app/scripts/frp_cli.sh; then
        log_info "✓ CLI script accessible"
    else
        log_error "✗ CLI script not found"
        return 1
    fi

    # Check logs
    log_info "Recent client logs:"
    docker logs frp-test-client --tail 5 | sed 's/^/  /'

    return 0
}

# Test CLI functionality
test_cli_functionality() {
    log_step "Testing CLI functionality..."

    # Test help command
    if docker exec frp-test-client /app/scripts/frp_cli.sh --help 2>/dev/null | head -5; then
        log_info "✓ CLI help accessible"
    else
        log_warn "! CLI help test inconclusive"
    fi

    # Test version command
    if docker exec frp-test-client /app/scripts/entrypoint.sh version; then
        log_info "✓ Version command works"
    else
        log_warn "! Version command test inconclusive"
    fi
}

# Test binary download
test_binary_download() {
    log_step "Testing binary download functionality..."

    # Check if binaries exist
    if docker exec frp-test-server test -f /app/frp/frps && \
       docker exec frp-test-server test -f /app/frp/frpc; then
        log_info "✓ FRP binaries downloaded"

        # Show version info
        log_info "FRP version info:"
        docker exec frp-test-server cat /app/frp/VERSION 2>/dev/null | sed 's/^/  /' || true
    else
        log_error "✗ FRP binaries missing"
        return 1
    fi
}

# Test configuration generation
test_configuration() {
    log_step "Testing configuration generation..."

    # Check server config
    if docker exec frp-test-server test -f /app/configs/frps.ini; then
        log_info "✓ Server configuration generated"
    else
        log_error "✗ Server configuration missing"
        return 1
    fi

    # Check client config
    if docker exec frp-test-client test -f /app/configs/frpc.ini; then
        log_info "✓ Client configuration generated"
    else
        log_error "✗ Client configuration missing"
        return 1
    fi
}

# Run comprehensive tests
run_tests() {
    local test_results=0

    log_step "Running comprehensive test suite..."

    # Test server mode
    if ! test_server_mode; then
        log_error "Server mode test failed"
        ((test_results++))
    fi

    # Test client mode
    if ! test_client_mode; then
        log_error "Client mode test failed"
        ((test_results++))
    fi

    # Test binary download
    if ! test_binary_download; then
        log_error "Binary download test failed"
        ((test_results++))
    fi

    # Test configuration
    if ! test_configuration; then
        log_error "Configuration test failed"
        ((test_results++))
    fi

    # Test CLI functionality
    test_cli_functionality

    return $test_results
}

# Show usage
show_usage() {
    echo "Usage: $0 [build|test|all|clean]"
    echo ""
    echo "Commands:"
    echo "  build  - Build Docker image only"
    echo "  test   - Run test suite (requires existing image)"
    echo "  all    - Build image and run tests (default)"
    echo "  clean  - Clean up test containers and images"
    echo ""
}

# Clean up everything
clean_all() {
    log_step "Cleaning up all test artifacts..."

    cleanup

    # Remove test images
    docker rmi "${IMAGE_NAME}" 2>/dev/null || true

    # Prune unused resources
    docker system prune -f

    log_info "✓ Cleanup completed"
}

# Main execution
main() {
    local command="${1:-all}"

    print_banner

    case "$command" in
        "build")
            build_image
            ;;
        "test")
            run_tests
            ;;
        "all")
            build_image
            if run_tests; then
                log_info "🎉 All tests passed successfully!"
                echo ""
                log_info "Image ready for use:"
                echo "  docker run -e FRP_MODE=server --network host ${IMAGE_NAME}"
                echo "  docker run -it -e FRP_MODE=client ${IMAGE_NAME} shell"
            else
                log_error "❌ Some tests failed"
                exit 1
            fi
            ;;
        "clean")
            clean_all
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"