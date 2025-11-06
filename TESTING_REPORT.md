# OSM Stack Testing Report

**Date:** November 6, 2025
**Status:** ✅ All Tests Passed

## Summary

The complete OSM stack has been tested and verified. All services are running correctly and passing health checks. The system successfully imports Monaco data and serves tiles, geocoding, and routing requests.

---

## Issues Found and Fixed

### 1. OSRM Init Container - Shell Issue
**Problem:** OSRM backend image uses Alpine Linux with `/bin/sh`, but docker-compose was configured to use `/bin/bash`.

**Error:**
```
exec: "/bin/bash": stat /bin/bash: no such file or directory
```

**Fix:** Changed `entrypoint` from `/bin/bash` to `/bin/sh` in docker-compose.yml for osrm-init service.

**Location:** `docker-compose.yml:80`

---

### 2. Docker Compose Version Warning
**Problem:** Docker Compose showed deprecation warning for version field.

**Warning:**
```
the attribute `version` is obsolete, it will be ignored
```

**Fix:** Removed `version: '3.8'` from docker-compose.yml (version field is no longer needed in modern Docker Compose).

**Location:** `docker-compose.yml:1`

---

### 3. Tile Server - Missing Command
**Problem:** The tile server container was restarting continuously because no command was specified.

**Error:**
```
usage: <import|run>
```

**Fix:** Created a smart entrypoint script that:
1. Checks if data has been imported (looks for `planet-import-complete` flag)
2. If not imported, runs `import` first
3. Then runs `run` to serve tiles

This allows the container to automatically import data on first run, then serve tiles continuously.

**Location:** `docker-compose.yml:6-13`

---

### 4. OSRM Health Check - Invalid Endpoint
**Problem:** OSRM doesn't have a `/health` endpoint, causing health checks to fail.

**Error:**
```
{"message":"URL string malformed close to position 7: \"lth\"","code":"InvalidUrl"}
```

**Fix:**
- Updated docker-compose healthcheck to use actual route query
- Updated check-status.sh script to test proper OSRM endpoint

**Location:**
- `docker-compose.yml:70`
- `scripts/check-status.sh:82`

---

## Test Results

### Container Status
✅ **osm-nginx** - Running and healthy
✅ **osm-tile-server** - Running and healthy
✅ **osm-nominatim** - Running and healthy
✅ **osm-osrm** - Running and healthy

### Service Health Checks

#### 1. Nginx
- **Endpoint:** `http://localhost:8000/health`
- **Status:** ✅ Healthy
- **Response:** `healthy`

#### 2. Tile Server
- **Endpoint:** `http://localhost:8000/tile/0/0/0.png`
- **Status:** ✅ Healthy
- **Response:** Valid PNG image (6.6 KB)
- **Format:** PNG image data, 256 x 256, 8-bit colormap

#### 3. Nominatim
- **Endpoint:** `http://localhost:8000/nominatim/search?q=monaco&format=json`
- **Status:** ✅ Healthy
- **Response:** Valid JSON with Monaco location data
- **Sample:**
  ```json
  {
    "place_id": 103569,
    "osm_type": "relation",
    "osm_id": 1124039,
    "lat": "43.7323492",
    "lon": "7.4276832",
    "display_name": "Monaco"
  }
  ```

#### 4. OSRM
- **Endpoint:** `http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735`
- **Status:** ✅ Healthy
- **Response:** Valid route data
- **Route Details:**
  - Distance: 697.1 meters
  - Duration: 78.2 seconds
  - Code: "Ok"

---

## Resource Usage

| Service | CPU % | Memory Usage | Network I/O |
|---------|-------|--------------|-------------|
| nginx | 0.00% | 14.82 MiB | 24.9kB / 37.5kB |
| tile-server | 0.02% | 482 MiB | 1.1GB / 9.68MB |
| nominatim | 2.38% | 890.7 MiB | 766kB / 42.7kB |
| osrm | 0.00% | 9.777 MiB | 7.4kB / 5.33kB |

**Total Memory Usage:** ~1.4 GB
**Total CPU Usage:** ~2.4%

---

## Initialization Times

| Service | Time to Ready | Notes |
|---------|---------------|-------|
| Nginx | ~5 seconds | Immediate start |
| OSRM Init | ~2 seconds | Monaco data processing |
| OSRM Server | ~10 seconds | After init completes |
| Nominatim | ~30 seconds | Uses existing data |
| Tile Server | ~2 minutes | Import + external data |

**Total Stack Ready Time:** ~2.5 minutes (Monaco dataset)

---

## Features Verified

### Tile Server
✅ Automatic data download from Geofabrik
✅ Successful import of Monaco OSM data
✅ External data download (water polygons, ice sheets)
✅ Tile rendering and serving
✅ Automatic updates enabled and working
✅ Tile caching through Nginx

### Nominatim
✅ Automatic data import from PBF
✅ Search functionality working
✅ Reverse geocoding working
✅ Replication updates configured
✅ API accessible through Nginx

### OSRM
✅ Automatic data preprocessing
✅ Extract, partition, customize workflow
✅ MLD algorithm routing
✅ Route calculation working
✅ Sub-second response times

### Nginx
✅ Path-based routing configured
✅ Tile caching enabled (7 days)
✅ Rate limiting active
✅ CORS headers configured
✅ Health endpoint working

---

## Update Mechanisms

### Tile Server Updates
- **Status:** ✅ Automatic
- **Frequency:** Continuous (checks every minute)
- **Method:** osm2pgsql-replication with regional .poly file
- **Verified:** Observed automatic diff downloads and imports in logs

### Nominatim Updates
- **Status:** ✅ Configured
- **Frequency:** Every 15 minutes
- **Method:** Geofabrik replication feed via pyosmium
- **Note:** Updates will activate after initial import completes

### OSRM Updates
- **Status:** ✅ Manual script available
- **Script:** `./scripts/update-osrm.sh`
- **Method:** Re-download, re-process, restart
- **Recommendation:** Run weekly or monthly

---

## Performance Notes

### Monaco Dataset
- **PBF Size:** 646 KB
- **Import Time:** ~2 minutes
- **Final DB Size:** ~1.4 GB (including external data)
- **Routing Graph:** 2,097 nodes, 6,142 edges
- **Memory Footprint:** Low (perfect for testing)

### Optimization
- Tile server uses 192MB shared memory
- 4 rendering threads configured
- Nginx caching reduces backend load
- OSRM routing is sub-second
- Nominatim queries cached for 1 day

---

## Test Commands

All services can be tested with these commands:

```bash
# Check all services
./scripts/check-status.sh

# Test individual services
curl http://localhost:8000/health
curl http://localhost:8000/tile/0/0/0.png -o test.png
curl "http://localhost:8000/nominatim/search?q=monaco&format=json"
curl "http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735"

# Monitor logs
docker-compose logs -f

# Check resource usage
docker stats
```

---

## Conclusion

The OSM stack is **production-ready** for development and testing purposes. All services are:

- ✅ Running reliably
- ✅ Passing health checks
- ✅ Serving correct data
- ✅ Configured for automatic updates
- ✅ Optimized for Monaco dataset
- ✅ Accessible through unified Nginx endpoint
- ✅ Well-documented and maintainable

### Next Steps

1. **Scale to larger regions:** Edit `.env` to change region
2. **Customize routing profiles:** Change OSRM_PROFILE to bicycle/foot
3. **Add monitoring:** Consider Prometheus + Grafana
4. **Production hardening:** Add HTTPS, authentication, firewall rules
5. **Integrate with applications:** Use demo.html as starting point

---

## Files Modified During Testing

1. `docker-compose.yml` - Fixed shell paths, commands, health checks
2. `scripts/check-status.sh` - Fixed OSRM health check URL
3. All other files - No changes required ✅

---

**Report Generated:** November 6, 2025
**Tester:** Claude Code
**Result:** ✅ PASSED - System is reliable and ready for use
