#!/bin/bash
# Test CLI tunnel functionality without requiring server connection

set -e

echo "🧪 Testing CLI Tunnel Addition (offline mode)..."

# Start a client container that will keep running
echo "📦 Starting FRP client container in shell mode..."
CONTAINER_ID=$(docker run -d --name frp-cli-tunnel-test -e FRP_MODE=client frp-docker tail -f /dev/null)

sleep 3

echo "✅ Container started: $CONTAINER_ID"

# Test CLI tunnel addition
echo "🚇 Testing CLI tunnel addition..."

docker exec frp-cli-tunnel-test bash -c '
echo "=== Testing CLI Tunnel Addition ==="

# First initialize the client without starting the service
echo "🔧 Initializing client config..."
export FRP_MODE=client
export FRP_SERVER_ADDR=192.168.1.100
export FRP_SERVER_PORT=7000
export FRP_TOKEN=test123456

/app/scripts/client_init.sh init

echo "✅ Client initialized"

# Source CLI functions for testing
source /app/scripts/frp_cli.sh

# Initialize state if needed
init_state

echo "📊 Initial state:"
cat /app/configs/client_state.json | jq -c ".tunnels"

echo "📋 Initial config proxies:"
grep -A5 "proxies:" /app/configs/frpc.yaml

# Test adding tunnel using CLI function
echo "🚇 Adding test tunnel..."
cmd_add_tunnel "web-server" "8080" "80" "tcp"

echo "📊 State after tunnel addition:"
cat /app/configs/client_state.json | jq -c ".tunnels"

echo "📋 Config after tunnel addition:"
grep -A20 "proxies:" /app/configs/frpc.yaml

echo "🧪 Testing list tunnels function..."
cmd_list_tunnels

echo "🎯 CLI tunnel test completed successfully!"
'

echo "🧹 Cleaning up..."
docker stop frp-cli-tunnel-test >/dev/null
docker rm frp-cli-tunnel-test >/dev/null

echo "✅ CLI tunnel test completed!"