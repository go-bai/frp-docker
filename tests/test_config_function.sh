#!/bin/bash
# Test tunnel configuration addition functionality

echo "🧪 Testing Tunnel Configuration Management..."

# Start container with tail to keep it running
CONTAINER_ID=$(docker run -d --name frp-config-test -e FRP_MODE=client frp-docker tail -f /dev/null)

echo "✅ Container started: $CONTAINER_ID"

sleep 3

# Test configuration management
docker exec frp-config-test bash -c '
echo "=== Direct Function Test ==="

# Set up environment
export CONFIG_DIR="/app/configs"
export CLIENT_STATE="/app/configs/client_state.json"
export CLIENT_CONFIG="/app/configs/frpc.yaml"

# Initialize directories
mkdir -p /app/configs

# Create basic config first
cat > /app/configs/frpc.yaml << "EOF"
# FRP Client Configuration - Auto Generated (YAML Format)
# Generated: 2025-10-16 15:38:00 UTC
# Container: FRP Docker v1.0.0

# Server connection
serverAddr: "192.168.1.100"
serverPort: 7000

# Authentication
auth:
  token: "test123456"

# Logging
log:
  to: "/app/logs/frpc.log"
  level: "info"
  maxDays: 7

# Transport settings
transport:
  tcpMux: true

# User settings
user: "frpc_user"

# Proxy configurations
proxies: []
EOF

echo "✅ Basic config created"
echo "📋 Initial config:"
cat /app/configs/frpc.yaml | tail -5

# Source client_init.sh to load functions
cd /app/scripts
source client_init.sh

echo ""
echo "🚇 Testing add_tunnel_to_config function..."

# Test adding first tunnel
add_tunnel_to_config "web-server" "8080" "80" "tcp"

echo "📋 Config after first tunnel:"
tail -15 /app/configs/frpc.yaml

echo ""
echo "🚇 Adding second tunnel..."

# Test adding second tunnel
add_tunnel_to_config "ssh-server" "22" "2222" "tcp"

echo "📋 Final config:"
tail -25 /app/configs/frpc.yaml

echo ""
echo "✅ Tunnel configuration test completed!"
'

# Cleanup
echo "🧹 Cleaning up..."
docker stop frp-config-test >/dev/null
docker rm frp-config-test >/dev/null

echo "✅ Test completed successfully!"