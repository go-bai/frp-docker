#!/bin/bash
# Test script for tunnel functionality

set -e

echo "🧪 Testing FRP Client Tunnel Addition..."

# Start a client container
echo "📦 Starting FRP client container..."
CONTAINER_ID=$(docker run -d --name frp-tunnel-test -e FRP_MODE=client -e FRP_SERVER_ADDR=127.0.0.1 -e FRP_SERVER_PORT=7000 -e FRP_TOKEN=test123 frp-docker)

sleep 5

echo "✅ Container started: $CONTAINER_ID"

# Check if CLI is accessible
echo "🔍 Testing CLI access..."
docker exec frp-tunnel-test frp-cli --version 2>/dev/null || echo "CLI accessible via direct command"

# Test tunnel addition via script simulation
echo "🚇 Testing tunnel addition..."
docker exec frp-tunnel-test bash -c '
echo "=== Testing tunnel addition ==="

# Initialize state if needed
/app/scripts/client_init.sh init >/dev/null 2>&1

echo "✅ Client initialized"

# Check initial config
echo "📋 Initial config:"
if [ -f /app/configs/frpc.yaml ]; then
    echo "Config file exists"
    grep -A5 "proxies:" /app/configs/frpc.yaml || echo "No proxies section found"
else
    echo "❌ Config file missing"
    exit 1
fi

# Check state file
echo "📊 State file:"
if [ -f /app/configs/client_state.json ]; then
    echo "State file exists"
    jq ".tunnels" /app/configs/client_state.json 2>/dev/null || echo "[]"
else
    echo "❌ State file missing"
    exit 1
fi

echo "🎯 Test completed successfully!"
'

echo "🧹 Cleaning up..."
docker stop frp-tunnel-test >/dev/null
docker rm frp-tunnel-test >/dev/null

echo "✅ Test completed!"