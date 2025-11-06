#!/bin/bash

# OSM Stack Status Checker
# Verifies all services are running and healthy
# Usage: ./scripts/check-status.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OSM Stack Status Check ===${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

NGINX_URL="http://localhost:${NGINX_PORT}"

# Function to check service status
check_service() {
    local service_name=$1
    local endpoint=$2
    local display_name=$3

    printf "%-30s" "$display_name:"

    if curl -s -f "$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Unhealthy${NC}"
        return 1
    fi
}

# Function to check docker container status
check_container() {
    local container_name=$1
    local display_name=$2

    printf "%-30s" "$display_name:"

    status=$(docker inspect -f '{{.State.Status}}' $container_name 2>/dev/null || echo "not found")

    if [ "$status" == "running" ]; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    elif [ "$status" == "not found" ]; then
        echo -e "${RED}✗ Not found${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ $status${NC}"
        return 1
    fi
}

echo -e "${YELLOW}Container Status:${NC}"
echo "----------------------------------------"

check_container "osm-nginx" "Nginx Proxy"
check_container "osm-tile-server" "Tile Server"
check_container "osm-nominatim" "Nominatim"
check_container "osm-osrm" "OSRM"

echo ""
echo -e "${YELLOW}Service Health:${NC}"
echo "----------------------------------------"

check_service "nginx" "${NGINX_URL}/health" "Nginx Health"
check_service "tiles" "${NGINX_URL}/tile/0/0/0.png" "Tile Server (via Nginx)"
check_service "nominatim" "${NGINX_URL}/nominatim/search?q=test&format=json" "Nominatim (via Nginx)"
check_service "osrm" "${NGINX_URL}/osrm/route/v1/driving/7.419,43.733;7.421,43.735" "OSRM Routing (via Nginx)"
check_service "osrm-match" "${NGINX_URL}/osrm/match/v1/driving/7.419,43.733;7.421,43.735?radiuses=50;50" "OSRM Match/Snapping (via Nginx)"

echo ""
echo -e "${YELLOW}Service Endpoints:${NC}"
echo "----------------------------------------"

echo -e "${GREEN}Tile Server:${NC}"
echo "  Base URL: ${NGINX_URL}/"
echo "  Example:  ${NGINX_URL}/tile/0/0/0.png"
echo ""

echo -e "${GREEN}Nominatim:${NC}"
echo "  Base URL: ${NGINX_URL}/nominatim/"
echo "  Search:   ${NGINX_URL}/nominatim/search?q=monaco&format=json"
echo "  Reverse:  ${NGINX_URL}/nominatim/reverse?lat=43.73&lon=7.42&format=json"
echo ""

echo -e "${GREEN}OSRM:${NC}"
echo "  Base URL: ${NGINX_URL}/osrm/"
echo "  Route:    ${NGINX_URL}/osrm/route/v1/driving/7.419,43.733;7.421,43.735?overview=false"
echo "  Table:    ${NGINX_URL}/osrm/table/v1/driving/7.419,43.733;7.421,43.735"
echo "  Nearest:  ${NGINX_URL}/osrm/nearest/v1/driving/7.419,43.733"
echo "  Match:    ${NGINX_URL}/osrm/match/v1/driving/7.419,43.733;7.420,43.734?radiuses=50;50"
echo ""

echo -e "${YELLOW}Volume Usage:${NC}"
echo "----------------------------------------"

# Check Docker volumes
docker volume ls --format "table {{.Name}}\t{{.Size}}" | grep "titan-map" || echo "No volumes found"

echo ""
echo -e "${YELLOW}Resource Usage:${NC}"
echo "----------------------------------------"

# Show container stats (brief)
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
    osm-nginx osm-tile-server osm-nominatim osm-osrm 2>/dev/null || \
    echo "Could not retrieve container stats"

echo ""
echo -e "${BLUE}=== Status Check Complete ===${NC}"
