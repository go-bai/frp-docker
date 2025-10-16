#!/bin/bash
##
## FRP Docker Test Runner
## Runs all test scripts in the tests directory
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Print header
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                        FRP DOCKER TEST RUNNER                                                         ║"
    echo "║                                      Comprehensive Test Suite                                                         ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run a single test
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo -e "${WHITE}Running test: $test_name${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if timeout 300 "$test_file"; then
        log_success "$test_name completed successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo ""
        return 0
    else
        log_error "$test_name failed or timed out"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        return 1
    fi
}

# Print summary
print_summary() {
    echo -e "${WHITE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                          TEST SUMMARY                                                                  ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${WHITE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC}      $PASSED_TESTS"
    echo -e "${RED}Failed:${NC}      $FAILED_TESTS"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
        return 1
    fi
}

# Main execution
main() {
    local test_type="${1:-all}"
    local tests_dir="$(dirname "$0")"

    print_header

    log_info "Starting FRP Docker test suite..."
    log_info "Test directory: $tests_dir"
    echo ""

    case "$test_type" in
        "all")
            log_info "Running all tests..."
            for test_file in "$tests_dir"/test_*.sh "$tests_dir"/demo_*.sh; do
                if [[ -f "$test_file" && -x "$test_file" ]]; then
                    run_test "$test_file" || true
                fi
            done
            ;;
        "unit")
            log_info "Running unit tests..."
            for test_file in "$tests_dir"/test_*.sh; do
                if [[ -f "$test_file" && -x "$test_file" ]]; then
                    run_test "$test_file" || true
                fi
            done
            ;;
        "demo")
            log_info "Running demonstrations..."
            for test_file in "$tests_dir"/demo_*.sh; do
                if [[ -f "$test_file" && -x "$test_file" ]]; then
                    run_test "$test_file" || true
                fi
            done
            ;;
        *)
            echo "Usage: $0 [all|unit|demo]"
            echo ""
            echo "  all   - Run all tests and demos (default)"
            echo "  unit  - Run only unit tests"
            echo "  demo  - Run only demonstrations"
            exit 1
            ;;
    esac

    echo ""
    print_summary
}

# Execute main function with all arguments
main "$@"