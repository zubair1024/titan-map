#!/bin/bash

# Quick Start Script for OSM Stack
# Usage: ./scripts/quickstart.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║     OSM Stack Quick Start                  ║"
echo "║     Tiles + Geocoding + Routing            ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is ready${NC}"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Load environment
export $(cat .env | grep -v '^#' | xargs)

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Region: $OSM_REGION"
echo "  Port: $NGINX_PORT"
echo ""

# Check if services are already running
if docker ps | grep -q "osm-tile-server"; then
    echo -e "${YELLOW}Services are already running!${NC}"
    read -p "Do you want to restart them? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restarting services...${NC}"
        docker-compose restart
        echo -e "${GREEN}✓ Services restarted${NC}"
    fi
else
    echo -e "${YELLOW}Starting services...${NC}"
    docker-compose up -d

    echo ""
    echo -e "${GREEN}✓ Services are starting${NC}"
    echo ""
    echo -e "${YELLOW}Initial data import is in progress...${NC}"
    echo "This will take 10-20 minutes for Monaco."
    echo ""
fi

echo -e "${BLUE}Waiting for services to be ready...${NC}"
echo "(This may take a few minutes on first start)"
echo ""

# Wait for nginx
echo -n "Checking nginx... "
for i in {1..30}; do
    if curl -s http://localhost:${NGINX_PORT}/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

# Wait for tile server
echo -n "Checking tile server... "
for i in {1..60}; do
    if curl -s http://localhost:${NGINX_PORT}/tile/0/0/0.png > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    sleep 5
    echo -n "."
done

# Wait for Nominatim
echo -n "Checking Nominatim... "
for i in {1..60}; do
    if curl -s "http://localhost:${NGINX_PORT}/nominatim/search?q=test&format=json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    sleep 5
    echo -n "."
done

# Wait for OSRM
echo -n "Checking OSRM... "
for i in {1..30}; do
    if curl -s http://localhost:${NGINX_PORT}/osrm/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════╗"
echo "║            Setup Complete!                 ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Service Endpoints:${NC}"
echo ""
echo -e "${GREEN}Base URL:${NC}"
echo "  http://localhost:${NGINX_PORT}"
echo ""
echo -e "${GREEN}Tiles:${NC}"
echo "  http://localhost:${NGINX_PORT}/tile/0/0/0.png"
echo ""
echo -e "${GREEN}Nominatim Search:${NC}"
echo "  http://localhost:${NGINX_PORT}/nominatim/search?q=monaco&format=json"
echo ""
echo -e "${GREEN}OSRM Routing:${NC}"
echo "  http://localhost:${NGINX_PORT}/osrm/route/v1/driving/7.419,43.733;7.421,43.735"
echo ""

echo -e "${YELLOW}Quick Test Commands:${NC}"
echo ""
echo "# Test tile server"
echo "curl -o test-tile.png http://localhost:${NGINX_PORT}/tile/0/0/0.png"
echo ""
echo "# Test Nominatim"
echo "curl 'http://localhost:${NGINX_PORT}/nominatim/search?q=monaco&format=json'"
echo ""
echo "# Test OSRM"
echo "curl 'http://localhost:${NGINX_PORT}/osrm/route/v1/driving/7.419,43.733;7.421,43.735?overview=false'"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Open demo.html in your browser to see a working example"
echo "2. Check service status: ./scripts/check-status.sh"
echo "3. View logs: docker-compose logs -f"
echo "4. Read full documentation in README.md"
echo ""

echo -e "${BLUE}Happy Mapping!${NC}"
