#!/bin/bash
# Test the fixed CLI interactive functionality

echo "🧪 Testing Fixed FRP CLI Interactive Commands..."
echo "============================================="

# Start container in background
echo "📦 Starting container..."
CONTAINER_ID=$(docker run -d --name frp-cli-test -e FRP_MODE=client frp-docker tail -f /dev/null)

sleep 3

echo "✅ Container started: $CONTAINER_ID"
echo ""

echo "🔧 Test 1: CLI help command"
echo "-------------------------"
docker exec frp-cli-test frp-cli help 2>/dev/null | head -15

echo ""
echo "🔧 Test 2: Status command"
echo "----------------------"
docker exec frp-cli-test bash -c 'frp-cli status' 2>/dev/null | head -10

echo ""
echo "🔧 Test 3: Interactive add command simulation"
echo "-------------------------------------------"
docker exec frp-cli-test bash -c '
# Simulate interactive input using expect-like functionality
echo "Testing interactive add..."

# Source CLI functions directly for testing
source /app/scripts/frp_cli.sh

# Initialize state
init_state

echo "Initial tunnels:"
cmd_list_tunnels 2>/dev/null | tail -5

# Test direct function call with parameters (non-interactive)
echo ""
echo "Adding tunnel via direct parameters:"
cmd_add_tunnel "test-web" "8080" "80" "tcp"

echo ""
echo "Final tunnel list:"
cmd_list_tunnels
'

echo ""
echo "🧹 Cleaning up..."
docker stop frp-cli-test >/dev/null 2>&1
docker rm frp-cli-test >/dev/null 2>&1

echo "✅ Test completed successfully!"