#!/bin/bash
# Demonstration of FRP CLI usage

echo "🚀 FRP CLI Tunnel Management Demonstration"
echo "========================================="
echo ""

echo "📦 Starting client container with persistent mode..."
docker run --rm -d --name frp-demo -e FRP_MODE=client frp-docker tail -f /dev/null

sleep 3

echo "✅ Container started successfully"
echo ""

echo "🔧 Example 1: Using CLI command directly"
echo "--------------------------------------"

# Show that frp-cli is available in PATH
docker exec frp-demo which frp-cli

echo ""
echo "🔧 Example 2: Adding tunnels via container commands"
echo "------------------------------------------------"

# Add tunnels using docker exec
docker exec frp-demo bash -c '
echo "Adding SSH tunnel (22 -> 2222)..."
source /app/scripts/frp_cli.sh
init_state
cmd_add_tunnel "ssh-tunnel" "22" "2222" "tcp"
echo ""

echo "Adding web server tunnel (8080 -> 80)..."
cmd_add_tunnel "web-server" "8080" "80" "tcp"
echo ""

echo "Current tunnel configuration:"
cmd_list_tunnels
'

echo ""
echo "🔧 Example 3: Viewing generated configuration"
echo "-------------------------------------------"

docker exec frp-demo cat /app/configs/frpc.yaml

echo ""
echo "🔧 Example 4: Viewing tunnel state"
echo "-------------------------------"

docker exec frp-demo jq "." /app/configs/client_state.json

echo ""
echo "🧹 Cleaning up..."
docker stop frp-demo >/dev/null

echo ""
echo "✅ Demo completed successfully!"
echo ""
echo "💡 To use interactively:"
echo "   docker run -it --name my-frp-client -e FRP_MODE=client frp-docker frp-cli"
echo ""
echo "💡 To start with server connection:"
echo '   docker run -it --name my-frp-client \'
echo '     -e FRP_MODE=client \'
echo '     -e FRP_SERVER_ADDR=your.server.com \'
echo '     -e FRP_SERVER_PORT=7000 \'
echo '     -e FRP_TOKEN=your_auth_token \'
echo '     frp-docker frp-cli'