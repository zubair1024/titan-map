# OSM Stack - Complete OpenStreetMap Services

A production-ready Docker Compose stack providing tile serving, geocoding, and routing services using OpenStreetMap data.

## Services

- **Tile Server** (`overv/openstreetmap-tile-server`) - Raster map tiles with automatic updates
- **Nominatim** (`mediagis/nominatim`) - Geocoding and reverse geocoding API
- **OSRM** (`ghcr.io/project-osrm/osrm-backend`) - High-performance routing engine
- **Nginx** - Reverse proxy with path-based routing and caching

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 8GB RAM minimum (4GB might work for Monaco)
- 20GB free disk space

### Initial Setup

1. **Clone or navigate to the project directory:**
   ```bash
   cd titan-map
   ```

2. **Review and customize configuration:**
   ```bash
   # Edit .env file to change region or settings
   nano .env
   ```

3. **Start the stack:**
   ```bash
   docker-compose up -d
   ```

4. **Monitor initialization (first run takes 10-20 minutes):**
   ```bash
   # Watch all services
   docker-compose logs -f

   # Or watch individual services
   docker-compose logs -f tile-server
   docker-compose logs -f nominatim
   docker-compose logs -f osrm-init
   ```

5. **Check service status:**
   ```bash
   ./scripts/check-status.sh
   ```

6. **Access services:**
   - All services: `http://localhost:8000`
   - Tiles: `http://localhost:8000/tile/0/0/0.png`
   - Nominatim: `http://localhost:8000/nominatim/search?q=monaco&format=json`
   - OSRM: `http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735`

## Service Details

### Tile Server

**Base Path:** `/` (root)

**Tile URL Format:** `http://localhost:8000/tile/{z}/{x}/{y}.png`

**Example Tile Request:**
```bash
# Zoom level 0, tile 0,0
curl http://localhost:8000/tile/0/0/0.png -o tile.png
```

**Features:**
- Automatic daily updates from Geofabrik
- On-demand tile rendering with caching
- OpenStreetMap Carto style
- 7-day tile cache via Nginx

**Configuration:**
- Edit `.env` to change `TILE_SERVER_THREADS` (rendering threads)
- Increase `TILE_SERVER_SHM_SIZE` for larger regions (256m+ recommended)

### Nominatim Geocoding

**Base Path:** `/nominatim/`

**Search (Forward Geocoding):**
```bash
# Search for a location
curl "http://localhost:8000/nominatim/search?q=monaco&format=json"

# Structured search
curl "http://localhost:8000/nominatim/search?street=rue&city=monaco&format=json"

# With address details
curl "http://localhost:8000/nominatim/search?q=monaco&format=json&addressdetails=1"
```

**Reverse Geocoding:**
```bash
# Get address from coordinates
curl "http://localhost:8000/nominatim/reverse?lat=43.73&lon=7.42&format=json"

# With zoom level
curl "http://localhost:8000/nominatim/reverse?lat=43.73&lon=7.42&zoom=18&format=json"
```

**Features:**
- Continuous updates from Geofabrik replication feed
- 1-day cache for search results via Nginx
- Rate limiting: 10 requests/second
- Full Nominatim API support

**Documentation:** [Nominatim API](https://nominatim.org/release-docs/latest/api/Overview/)

### OSRM Routing

**Base Path:** `/osrm/`

**Route (Get directions):**
```bash
# Basic route between two points (lon,lat format)
curl "http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735"

# Route with geometry
curl "http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735?overview=full&geometries=geojson"

# Route with steps
curl "http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735?steps=true"
```

**Table (Distance matrix):**
```bash
# Get travel times between multiple points
curl "http://localhost:8000/osrm/table/v1/driving/7.419,43.733;7.421,43.735;7.425,43.740"
```

**Nearest (Snap to road):**
```bash
# Find nearest road to coordinate
curl "http://localhost:8000/osrm/nearest/v1/driving/7.419,43.733?number=3"
```

**Features:**
- Multi-Level Dijkstra (MLD) algorithm
- Car routing profile (bicycle and foot available)
- Rate limiting: 20 requests/second
- Manual update process (see below)

**Documentation:** [OSRM API](http://project-osrm.org/docs/v5.24.0/api/)

## Configuration

### Environment Variables

Edit `.env` file to customize:

```bash
# Region Configuration
OSM_REGION=monaco
PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf
POLY_URL=https://download.geofabrik.de/europe/monaco.poly
REPLICATION_URL=https://download.geofabrik.de/europe/monaco-updates/

# Service Ports
NGINX_PORT=8000

# Tile Server Settings
TILE_SERVER_THREADS=4
TILE_SERVER_SHM_SIZE=192m

# OSRM Settings
OSRM_PROFILE=car  # Options: car, bicycle, foot

# Update Settings
ENABLE_TILE_UPDATES=enabled
ENABLE_NOMINATIM_UPDATES=true
```

### Switching Regions

**Small Test Regions (Included in .env):**

1. **Monaco** - 646 KB (Default, fastest)
2. **Liechtenstein** - 3.1 MB
3. **Maldives** - ~2-3 MB

**To switch regions:**

1. Edit `.env` and uncomment your desired region
2. Remove existing data:
   ```bash
   docker-compose down -v
   ```
3. Start fresh:
   ```bash
   docker-compose up -d
   ```

**For other regions:**

1. Find your region on [Geofabrik Downloads](https://download.geofabrik.de/)
2. Copy the PBF URL, Poly URL, and update URL
3. Update `.env` with new URLs
4. Reset and restart as above

## Updates

### Tile Server Updates

**Automatic:** Updates are enabled by default and run automatically.

The tile server checks for updates every minute and applies them incrementally.

**Monitor updates:**
```bash
docker-compose logs -f tile-server | grep -i update
```

**Disable updates:**
```bash
# In .env
ENABLE_TILE_UPDATES=disabled
```

### Nominatim Updates

**Automatic:** Continuous replication is enabled by default.

Nominatim checks for updates every 15 minutes (900 seconds).

**Monitor updates:**
```bash
docker-compose logs -f nominatim | grep -i replication
```

**Manual update trigger:**
```bash
docker-compose exec nominatim nominatim replication --once
```

**Check replication status:**
```bash
docker-compose exec nominatim nominatim replication --status
```

### OSRM Updates

**Manual Process Required:** OSRM does not support incremental updates.

**Update procedure:**
```bash
./scripts/update-osrm.sh
```

This script will:
1. Stop OSRM service
2. Backup existing data
3. Download fresh OSM data
4. Re-process routing graph (extract, partition, customize)
5. Restart OSRM service

**Recommended update frequency:** Weekly or monthly

**Change routing profile:**
```bash
# Edit .env
OSRM_PROFILE=bicycle  # or foot

# Run update script
./scripts/update-osrm.sh
```

## Monitoring & Maintenance

### Check Service Status

```bash
./scripts/check-status.sh
```

This displays:
- Container running status
- Service health checks
- API endpoints with examples
- Volume usage
- Resource consumption

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f tile-server
docker-compose logs -f nominatim
docker-compose logs -f osrm
docker-compose logs -f nginx

# Last 100 lines
docker-compose logs --tail=100
```

### Resource Monitoring

```bash
# Real-time stats
docker stats osm-nginx osm-tile-server osm-nominatim osm-osrm

# Volume sizes
docker volume ls
docker system df -v
```

### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart tile-server
docker-compose restart nominatim
docker-compose restart osrm
```

### Clean Restart

```bash
# Stop services
docker-compose down

# Start services
docker-compose up -d
```

### Complete Reset

**Warning:** This deletes all imported data!

```bash
# Stop and remove volumes
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Troubleshooting

### Services Not Starting

**Check logs:**
```bash
docker-compose logs
```

**Common issues:**
- Insufficient memory: Increase Docker memory limit to 8GB+
- Port conflicts: Change `NGINX_PORT` in `.env`
- Disk space: Ensure 20GB+ free space

### Tile Server Issues

**Tiles not rendering:**
```bash
# Check import progress
docker-compose logs tile-server | grep -i import

# Check for errors
docker-compose logs tile-server | grep -i error
```

**Slow rendering:**
- Increase `TILE_SERVER_THREADS` in `.env`
- Increase `TILE_SERVER_SHM_SIZE` to 256m or 512m
- Wait for initial tile cache to build

### Nominatim Issues

**Search not working:**
```bash
# Check import status
docker-compose logs nominatim | grep -i import

# Test direct connection
docker-compose exec nominatim curl localhost:8080/search?q=test&format=json
```

**Import taking too long:**
- Normal for first run (10+ minutes for Monaco)
- Check disk I/O performance
- Ensure sufficient memory (4GB+)

### OSRM Issues

**Routing not working:**
```bash
# Check initialization
docker-compose logs osrm-init

# Check if files exist
docker run --rm -v titan-map_osrm-data:/data alpine ls -lh /data/

# Verify OSRM is running
docker-compose exec osrm curl localhost:5000/health
```

**Preprocessing failed:**
- Check available memory (need 2GB+ for Monaco)
- Verify PBF download completed
- Check logs: `docker-compose logs osrm-init`

### Nginx Issues

**502 Bad Gateway:**
- Backend service not ready yet (wait 5 minutes)
- Check backend health: `docker-compose ps`
- Test direct connection to backend

**Caching problems:**
```bash
# Clear nginx cache
docker-compose exec nginx sh -c "rm -rf /var/cache/nginx/*"
docker-compose restart nginx
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Client Request                     │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  Nginx (Port 8000)│
              │  Reverse Proxy    │
              └────────┬──────────┘
                       │
        ───────────────┼───────────────
        │              │              │
        ▼              ▼              ▼
┌────────────┐  ┌────────────┐  ┌─────────┐
│Tile Server │  │ Nominatim  │  │  OSRM   │
│  (Port 80) │  │(Port 8080) │  │(Port 5000)
│            │  │            │  │         │
│  Renders   │  │  Geocodes  │  │  Routes │
│   Tiles    │  │ Addresses  │  │         │
└─────┬──────┘  └─────┬──────┘  └────┬────┘
      │               │               │
      ▼               ▼               ▼
┌──────────┐    ┌──────────┐    ┌─────────┐
│PostgreSQL│    │PostgreSQL│    │ Custom  │
│+ Tile    │    │+ Search  │    │ Binary  │
│  Cache   │    │  Index   │    │ Format  │
└──────────┘    └──────────┘    └─────────┘
```

### Data Flow

1. **OSM PBF Data** (Monaco: 646 KB)
   - Downloaded from Geofabrik
   - Imported into each service independently

2. **Tile Server:**
   - Imports to PostgreSQL/PostGIS
   - Renders tiles on-demand
   - Caches rendered tiles

3. **Nominatim:**
   - Imports to PostgreSQL/PostGIS
   - Builds search indexes
   - Updates via replication

4. **OSRM:**
   - Preprocesses to binary format
   - Loads routing graph into memory
   - Serves routing queries

### Volumes

```
titan-map_tile-data       # PostgreSQL database for tiles
titan-map_tile-cache      # Rendered tile cache
titan-map_nominatim-data  # PostgreSQL database for geocoding
titan-map_nominatim-flatnode  # Node storage for Nominatim
titan-map_osrm-data       # Processed routing data
titan-map_nginx-cache     # Nginx cache for tiles and queries
```

## Performance Optimization

### For Monaco (Default)

Current settings are optimized for Monaco:
- 4 rendering threads
- 192MB shared memory
- Moderate caching

### For Larger Regions

**Increase resources in .env:**
```bash
TILE_SERVER_THREADS=8
TILE_SERVER_SHM_SIZE=512m
```

**Increase Docker memory:**
- Small countries (< 100MB PBF): 16GB RAM
- Medium countries (1GB PBF): 32GB RAM
- Large countries (5GB+ PBF): 64GB+ RAM

**Enable aggressive caching:**

Edit `nginx.conf`:
```nginx
proxy_cache_valid 200 30d;  # Cache tiles for 30 days
max_size=100g;              # Increase tile cache size
```

### Production Optimizations

1. **Use SSD storage** for Docker volumes
2. **Separate servers** for each service at scale
3. **Add CDN** (Cloudflare) for tile delivery
4. **Enable Varnish** for additional caching layer
5. **Use read replicas** for PostgreSQL databases
6. **Monitor** with Prometheus + Grafana

## API Integration Examples

### Leaflet Map with Custom Tiles

```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
    <div id="map" style="width: 100%; height: 600px;"></div>
    <script>
        var map = L.map('map').setView([43.73, 7.42], 13);

        L.tileLayer('http://localhost:8000/tile/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 19
        }).addTo(map);
    </script>
</body>
</html>
```

### Geocoding with JavaScript

```javascript
// Search for location
async function geocode(query) {
    const response = await fetch(
        `http://localhost:8000/nominatim/search?q=${encodeURIComponent(query)}&format=json`
    );
    return await response.json();
}

// Reverse geocoding
async function reverseGeocode(lat, lon) {
    const response = await fetch(
        `http://localhost:8000/nominatim/reverse?lat=${lat}&lon=${lon}&format=json`
    );
    return await response.json();
}

// Example usage
geocode('monaco').then(results => console.log(results));
reverseGeocode(43.73, 7.42).then(result => console.log(result));
```

### Routing with JavaScript

```javascript
async function getRoute(start, end) {
    const [startLon, startLat] = start;
    const [endLon, endLat] = end;

    const response = await fetch(
        `http://localhost:8000/osrm/route/v1/driving/${startLon},${startLat};${endLon},${endLat}?overview=full&geometries=geojson`
    );
    return await response.json();
}

// Example: Route in Monaco
getRoute([7.419, 43.733], [7.421, 43.735])
    .then(route => {
        console.log('Distance:', route.routes[0].distance, 'meters');
        console.log('Duration:', route.routes[0].duration, 'seconds');
        console.log('Geometry:', route.routes[0].geometry);
    });
```

## Resource Requirements

### Monaco (Default - 646 KB PBF)

- **RAM:** 4-8GB
- **CPU:** 2-4 cores
- **Storage:** 10-20GB
- **Import Time:** 10-15 minutes

### Liechtenstein (3.1 MB PBF)

- **RAM:** 8GB
- **CPU:** 4 cores
- **Storage:** 20-30GB
- **Import Time:** 20-30 minutes

### Small Country (100 MB PBF)

- **RAM:** 16GB
- **CPU:** 8 cores
- **Storage:** 50-100GB
- **Import Time:** 2-4 hours

### Large Country (1 GB+ PBF)

- **RAM:** 32-64GB
- **CPU:** 16+ cores
- **Storage:** 200GB-1TB
- **Import Time:** 12-48 hours

## Security Considerations

### Development Use

Current configuration is suitable for:
- Local development
- Testing
- Internal networks

### Production Use

For production deployment, add:

1. **HTTPS/TLS:**
   ```nginx
   listen 443 ssl http2;
   ssl_certificate /path/to/cert.pem;
   ssl_certificate_key /path/to/key.pem;
   ```

2. **Rate Limiting:** Already configured in nginx.conf

3. **Authentication:**
   ```nginx
   auth_basic "Restricted";
   auth_basic_user_file /etc/nginx/.htpasswd;
   ```

4. **Firewall:**
   ```bash
   # Only allow specific IPs
   iptables -A INPUT -p tcp --dport 8000 -s YOUR_IP -j ACCEPT
   iptables -A INPUT -p tcp --dport 8000 -j DROP
   ```

5. **CORS:** Already configured for all services

## License

This stack uses the following open-source components:

- **OpenStreetMap Data:** [ODbL License](https://www.openstreetmap.org/copyright)
- **Tile Server:** [GPL v3.0](https://github.com/Overv/openstreetmap-tile-server)
- **Nominatim:** [GPL v2.0](https://github.com/osm-search/Nominatim)
- **OSRM:** [BSD 2-Clause License](https://github.com/Project-OSRM/osrm-backend)
- **Nginx:** [BSD-like License](http://nginx.org/LICENSE)

## Support & Resources

### Documentation

- [OpenStreetMap Wiki](https://wiki.openstreetmap.org/)
- [Nominatim Documentation](https://nominatim.org/release-docs/latest/)
- [OSRM Documentation](http://project-osrm.org/docs/)
- [Leaflet Documentation](https://leafletjs.com/reference.html)

### Data Sources

- [Geofabrik Downloads](https://download.geofabrik.de/) - OSM extracts
- [OSM Planet](https://planet.openstreetmap.org/) - Full planet file

### Community

- [OpenStreetMap Forum](https://forum.openstreetmap.org/)
- [OSRM GitHub Issues](https://github.com/Project-OSRM/osrm-backend/issues)
- [Nominatim GitHub Issues](https://github.com/osm-search/Nominatim/issues)

## Contributing

Issues and pull requests welcome!

## Acknowledgments

Built with these excellent projects:
- [overv/openstreetmap-tile-server](https://github.com/Overv/openstreetmap-tile-server)
- [mediagis/nominatim-docker](https://github.com/mediagis/nominatim-docker)
- [Project-OSRM](https://github.com/Project-OSRM/osrm-backend)
- [OpenStreetMap](https://www.openstreetmap.org/)
