#!/bin/bash
# Advanced test script for CLI tunnel management

set -e

echo "🧪 Advanced FRP CLI Tunnel Management Test..."

# Start a client container
echo "📦 Starting FRP client container..."
CONTAINER_ID=$(docker run -d --name frp-cli-tunnel-test -e FRP_MODE=client frp-docker)

sleep 5

echo "✅ Container started: $CONTAINER_ID"

# Test CLI tunnel addition using expect-like simulation
echo "🚇 Testing CLI tunnel addition..."

# Create a test script that will interact with the CLI
docker exec frp-cli-tunnel-test bash -c '
cat > /tmp/test_cli.sh << '"'"'EOF'"'"'
#!/bin/bash
echo "=== Testing CLI Tunnel Management ==="

# Function to test add command with parameters
test_add_command() {
    echo "Testing add command with parameters..."

    # Source the CLI functions directly for testing
    source /app/scripts/frp_cli.sh

    # Initialize state
    init_state

    echo "Initial state:"
    cat /app/configs/client_state.json | jq "."

    # Test adding a tunnel via function call
    echo "Adding test tunnel..."
    cmd_add_tunnel "test-ssh" "22" "2222" "tcp" || echo "Add command failed"

    echo "State after adding tunnel:"
    cat /app/configs/client_state.json | jq ".tunnels"

    echo "Config file after adding tunnel:"
    cat /app/configs/frpc.yaml | grep -A10 "proxies:"
}

test_add_command
EOF

chmod +x /tmp/test_cli.sh
/tmp/test_cli.sh
'

echo "🧹 Cleaning up..."
docker stop frp-cli-tunnel-test >/dev/null
docker rm frp-cli-tunnel-test >/dev/null

echo "✅ Advanced test completed!"