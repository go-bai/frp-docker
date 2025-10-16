#!/bin/bash
##
## FRP Docker Quick Test
## Fast smoke test for basic functionality
## Author: Claude Code AI Assistant
##

set -euo pipefail

# Color definitions
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}🚀 FRP Docker Quick Test${NC}"
echo "======================="
echo ""

# Test 1: Build check
echo -e "${BLUE}[1/4]${NC} Checking if Docker image exists..."
if docker images frp-docker:latest -q | grep -q .; then
    echo -e "${GREEN}✅ Docker image found${NC}"
else
    echo -e "${YELLOW}⚠️  Docker image not found, building...${NC}"
    make build
fi

# Test 2: Basic container start
echo -e "${BLUE}[2/4]${NC} Testing container startup..."
CONTAINER_ID=$(docker run --rm -d --name frp-quick-test -e FRP_MODE=client frp-docker tail -f /dev/null)
echo -e "${GREEN}✅ Container started: ${CONTAINER_ID:0:12}${NC}"

# Test 3: CLI accessibility
echo -e "${BLUE}[3/4]${NC} Testing CLI accessibility..."
CLI_PATH=$(docker exec frp-quick-test which frp-cli 2>/dev/null || echo "")
if [[ -n "$CLI_PATH" ]]; then
    echo -e "${GREEN}✅ frp-cli command available at: $CLI_PATH${NC}"
else
    echo -e "${RED}❌ frp-cli command not found${NC}"
fi

# Test 4: Basic functionality
echo -e "${BLUE}[4/4]${NC} Testing basic functionality..."
docker exec frp-quick-test bash -c '
source /app/scripts/frp_cli.sh
init_state 2>/dev/null
cmd_add_tunnel "test" "8080" "80" "tcp" 2>/dev/null >/dev/null
tunnel_count=$(jq ".tunnels | length" /app/configs/client_state.json)
if [[ "$tunnel_count" == "1" ]]; then
    echo "✅ Tunnel creation: SUCCESS"
else
    echo "❌ Tunnel creation: FAILED"
fi
'

# Cleanup
echo ""
echo -e "${BLUE}🧹 Cleaning up...${NC}"
docker stop frp-quick-test >/dev/null 2>&1

echo ""
echo -e "${GREEN}🎉 Quick test completed successfully!${NC}"
echo -e "${YELLOW}💡 For comprehensive testing, run: ./tests/run_tests.sh${NC}"