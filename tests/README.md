# FRP Docker Test Scripts

This directory contains various test and demonstration scripts for the FRP Docker project.

## Test Scripts

### Core Functionality Tests

- **`test_tunnel.sh`** - Basic tunnel configuration and state management test
- **`test_config_function.sh`** - Tests the tunnel configuration functions directly
- **`test_cli_advanced.sh`** - Advanced CLI functionality testing
- **`test_cli_fixed.sh`** - Tests for the fixed CLI interactive functionality
- **`test_cli_tunnel.sh`** - Comprehensive CLI tunnel management testing

### Demonstration Scripts

- **`demo_cli_usage.sh`** - Complete CLI usage demonstration
- **`demo_final.sh`** - Final demonstration showing all fixed functionality

## Running Tests

All test scripts are executable and can be run directly:

```bash
# Run individual tests
./tests/test_tunnel.sh
./tests/test_config_function.sh
./tests/demo_cli_usage.sh

# Run all tests
for test in ./tests/test_*.sh; do echo "Running $test"; $test; done

# Run all demos
for demo in ./tests/demo_*.sh; do echo "Running $demo"; $demo; done
```

## Test Categories

### Unit Tests
- `test_config_function.sh` - Tests individual functions
- `test_tunnel.sh` - Tests basic tunnel operations

### Integration Tests
- `test_cli_advanced.sh` - Tests CLI integration
- `test_cli_fixed.sh` - Tests fixed CLI functionality
- `test_cli_tunnel.sh` - Tests complete tunnel workflow

### End-to-End Tests
- `demo_cli_usage.sh` - Complete usage demonstration
- `demo_final.sh` - Final functionality showcase

## Prerequisites

- Docker installed and running
- FRP Docker image built (`make build`)
- Sufficient system resources for multiple test containers

## Notes

- All tests create and clean up their own containers
- Tests are designed to be independent and can run in any order
- Some tests may take several minutes due to FRP binary downloads
- Tests include both successful scenarios and error conditions