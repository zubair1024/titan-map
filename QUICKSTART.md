# Quick Start Guide

## 🚀 Get Started in 3 Steps

### 1. Start Services
```bash
./scripts/quickstart.sh
# OR
make quickstart
# OR
docker-compose up -d
```

### 2. Wait for Initialization
First run takes **10-20 minutes** for Monaco data import.

Monitor progress:
```bash
docker-compose logs -f
```

### 3. Test Services
```bash
make test
# OR
./scripts/check-status.sh
```

---

## 📍 Service URLs

| Service | URL | Example |
|---------|-----|---------|
| **All Services** | `http://localhost:8000` | - |
| **Tiles** | `/tile/{z}/{x}/{y}.png` | `http://localhost:8000/tile/0/0/0.png` |
| **Nominatim** | `/nominatim/search?q=...` | `http://localhost:8000/nominatim/search?q=monaco&format=json` |
| **OSRM** | `/osrm/route/v1/driving/...` | `http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735` |

---

## 🎯 Common Commands

```bash
# Start services
make start

# Check status
make status

# View logs
make logs

# Stop services
make stop

# Restart services
make restart

# Update OSRM data
make update-osrm

# Open demo page
make demo

# Clean everything (removes data!)
make clean
```

---

## 🧪 Quick Tests

### Test Tiles
```bash
curl -o tile.png http://localhost:8000/tile/0/0/0.png
open tile.png
```

### Test Nominatim
```bash
curl 'http://localhost:8000/nominatim/search?q=monaco&format=json' | jq
```

### Test OSRM
```bash
curl 'http://localhost:8000/osrm/route/v1/driving/7.419,43.733;7.421,43.735?overview=false' | jq
```

---

## 🌍 Demo Application

Open `demo.html` in your browser for an interactive map with:
- ✅ Custom tile server
- ✅ Location search (Nominatim)
- ✅ Route calculation (OSRM)

```bash
open demo.html
# OR
make demo
```

---

## 🔄 Changing Regions

1. Edit `.env` file
2. Uncomment your desired region (or add custom)
3. Clean and restart:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

### Available Test Regions

| Region | Size | Import Time |
|--------|------|-------------|
| **Monaco** (default) | 646 KB | 10-15 min |
| **Liechtenstein** | 3.1 MB | 20-30 min |
| **Maldives** | 2-3 MB | 20-30 min |

---

## 🔍 Troubleshooting

### Services not ready?
```bash
# Check logs
docker-compose logs tile-server
docker-compose logs nominatim
docker-compose logs osrm-init
```

### Import taking too long?
- First import can take 10-20 minutes for Monaco
- Larger regions take longer (see README.md)
- Check Docker has enough memory (8GB recommended)

### Port 8000 already in use?
```bash
# Edit .env and change NGINX_PORT
nano .env
# Then restart
docker-compose restart nginx
```

### Reset everything?
```bash
make clean
# Then start fresh
make start
```

---

## 📚 Full Documentation

See [README.md](README.md) for:
- Complete API documentation
- Integration examples
- Performance tuning
- Production deployment
- Troubleshooting guide

---

## 🆘 Need Help?

1. Check service status: `./scripts/check-status.sh`
2. View logs: `docker-compose logs -f [service-name]`
3. Read full docs: `README.md`
4. Check configuration: `.env`

---

## ⚡ Pro Tips

- Use `make` commands for convenience
- Monitor first import with `docker-compose logs -f`
- Test individual services before integrating
- Start with Monaco before trying larger regions
- Check disk space regularly: `docker system df`

---

**Happy Mapping! 🗺️**
