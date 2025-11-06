#!/bin/bash

# OSRM Update Script
# Downloads fresh OSM data and re-processes for routing
# Usage: ./scripts/update-osrm.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== OSRM Update Script ===${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Verify required variables
if [ -z "$PBF_URL" ] || [ -z "$OSM_REGION" ] || [ -z "$OSRM_PROFILE" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Required: PBF_URL, OSM_REGION, OSRM_PROFILE"
    exit 1
fi

echo -e "${YELLOW}Region:${NC} $OSM_REGION"
echo -e "${YELLOW}Profile:${NC} $OSRM_PROFILE"
echo -e "${YELLOW}PBF URL:${NC} $PBF_URL"
echo ""

# Confirm with user
read -p "This will stop OSRM and re-process data. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${GREEN}Step 1: Stopping OSRM service...${NC}"
docker-compose stop osrm

echo ""
echo -e "${GREEN}Step 2: Backing up old data...${NC}"
docker run --rm -v titan-map_osrm-data:/data -v $(pwd)/backups:/backup \
    alpine tar czf /backup/osrm-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data . 2>/dev/null || \
    echo "No existing data to backup"

echo ""
echo -e "${GREEN}Step 3: Cleaning old OSRM files...${NC}"
docker run --rm -v titan-map_osrm-data:/data alpine \
    sh -c "rm -f /data/*.osrm* /data/*.osm.pbf"

echo ""
echo -e "${GREEN}Step 4: Downloading fresh OSM data...${NC}"
docker run --rm -v titan-map_osrm-data:/data alpine \
    wget -O /data/${OSM_REGION}-latest.osm.pbf ${PBF_URL}

echo ""
echo -e "${GREEN}Step 5: Extracting routing data...${NC}"
docker run --rm -t -v titan-map_osrm-data:/data \
    ghcr.io/project-osrm/osrm-backend \
    osrm-extract -p /opt/${OSRM_PROFILE}.lua /data/${OSM_REGION}-latest.osm.pbf

echo ""
echo -e "${GREEN}Step 6: Partitioning routing graph...${NC}"
docker run --rm -t -v titan-map_osrm-data:/data \
    ghcr.io/project-osrm/osrm-backend \
    osrm-partition /data/${OSM_REGION}-latest.osrm

echo ""
echo -e "${GREEN}Step 7: Customizing routing weights...${NC}"
docker run --rm -t -v titan-map_osrm-data:/data \
    ghcr.io/project-osrm/osrm-backend \
    osrm-customize /data/${OSM_REGION}-latest.osrm

echo ""
echo -e "${GREEN}Step 8: Starting OSRM service...${NC}"
docker-compose start osrm

echo ""
echo -e "${GREEN}Step 9: Waiting for OSRM to be ready...${NC}"
sleep 5

# Check if OSRM is healthy
for i in {1..30}; do
    if curl -s http://localhost:${NGINX_PORT}/osrm/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OSRM is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
echo ""
echo "Test routing with:"
echo "curl 'http://localhost:${NGINX_PORT}/osrm/route/v1/driving/7.419,43.733;7.421,43.735?overview=false'"
