# GPS Snapping & Map Matching Guide

Your OSM stack includes **OSRM** with full snapping capabilities for cleaning GPS data and matching traces to roads.

---

## Quick Answer: Which Service to Use?

**For multiple GPS coordinates from a trip:** Use **OSRM Match** ✅

| Your Need | Use This | Endpoint |
|-----------|----------|----------|
| Snap single point to road | OSRM Nearest | `/osrm/nearest/v1/driving/{lon},{lat}` |
| Snap entire GPS trip/trace | **OSRM Match** ✅ | `/osrm/match/v1/driving/{coords}` |
| Real-time UI snapping | OSRM Nearest | `/osrm/nearest/v1/driving/{lon},{lat}` |
| Clean noisy GPS tracks | **OSRM Match** ✅ | `/osrm/match/v1/driving/{coords}` |

---

## ⚠️ Critical: "NoMatch" Error Fix

**Problem:** Getting `{"code":"NoMatch","message":"Could not match the trace."}`?

**Solution:** OSRM's default search radius is only **5 meters**. You MUST add the `radiuses` parameter!

```bash
# ❌ FAILS - No radiuses parameter
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.420,43.734"

# ✅ WORKS - With 50m radius (one per coordinate)
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.420,43.734?radiuses=50;50"
```

**See [OSRM_MATCH_QUICK_FIX.md](./OSRM_MATCH_QUICK_FIX.md) for complete troubleshooting.**

---

## 1. OSRM Match - For GPS Trips ✅

**Best for:** Multiple GPS coordinates from a trip that you want to snap to roads.

### Why Match vs Nearest?

| Feature | Match (Use This!) | Nearest |
|---------|-------------------|---------|
| Input | Entire trip at once | One point at a time |
| Output | Connected route + snapped points | Individual points |
| API calls | 1 | N (one per point) |
| Accuracy | Understands trajectory | Independent points |
| GPS noise handling | Excellent | Poor |

### Complete Example

```javascript
async function snapTripToRoads(coordinates) {
  // Your GPS trip: [[lon, lat], [lon, lat], ...]
  const coords = coordinates.map(c => `${c[0]},${c[1]}`).join(';');

  // Set 50m search radius for each point (adjust based on GPS quality)
  const radiuses = coordinates.map(() => 50).join(';');

  const url = `http://localhost:8000/osrm/match/v1/driving/${coords}?` +
              `overview=full&geometries=geojson&radiuses=${radiuses}`;

  const response = await fetch(url);
  const data = await response.json();

  if (data.code !== 'Ok') {
    throw new Error(`Match failed: ${data.message || data.code}`);
  }

  return {
    // Snapped coordinates for EACH of your input points
    snappedPoints: data.tracepoints.map(tp => ({
      coordinates: tp.location,        // [lon, lat] snapped to road
      roadName: tp.name,                // Name of the road
      distanceFromOriginal: tp.distance // How far we moved it (meters)
    })),

    // Full route geometry (includes extra points on roads between yours)
    routeGeometry: data.matchings[0].geometry.coordinates,

    // Trip statistics
    totalDistance: data.matchings[0].distance,  // meters
    totalDuration: data.matchings[0].duration,  // seconds
    confidence: data.matchings[0].confidence    // 0-1 quality score
  };
}

// Usage
const myTrip = [
  [7.419, 43.733],
  [7.4195, 43.7335],
  [7.420, 43.734],
  [7.4205, 43.7345],
  [7.421, 43.735]
];

const result = await snapTripToRoads(myTrip);

// Get snapped coordinate for each input point
result.snappedPoints.forEach((point, i) => {
  console.log(`Point ${i + 1}:`);
  console.log(`  Original: ${myTrip[i]}`);
  console.log(`  Snapped:  ${point.coordinates}`);
  console.log(`  Road:     ${point.roadName}`);
  console.log(`  Moved:    ${point.distanceFromOriginal.toFixed(1)}m`);
});

console.log(`\nTotal distance: ${result.totalDistance.toFixed(1)}m`);
console.log(`Total duration: ${result.totalDuration.toFixed(1)}s`);
console.log(`Match confidence: ${result.confidence.toFixed(2)}`);
```

### Test It Now

```bash
# Working example (note the radiuses parameter!)
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734;7.4205,43.7345;7.421,43.735?overview=full&geometries=geojson&radiuses=50;50;50;50;50" | jq
```

### With Timestamps (Recommended!)

If you have timestamps, include them for better accuracy:

```javascript
const tripWithTime = {
  coordinates: [[7.419, 43.733], [7.420, 43.734], [7.421, 43.735]],
  timestamps: [1699350000, 1699350010, 1699350020] // Unix timestamps
};

const coords = tripWithTime.coordinates.map(c => `${c[0]},${c[1]}`).join(';');
const radiuses = tripWithTime.coordinates.map(() => 50).join(';');
const timestamps = tripWithTime.timestamps.join(';');

const url = `http://localhost:8000/osrm/match/v1/driving/${coords}?` +
            `radiuses=${radiuses}&timestamps=${timestamps}&` +
            `overview=full&geometries=geojson`;
```

### Choosing Search Radius

| GPS Quality | Radius | Use Case |
|-------------|--------|----------|
| High-precision (vehicle tracker) | `10` | Accurate GPS, close to roads |
| Good (phone outdoors) | `50` | **Default - works for most cases** |
| Poor (urban/indoor) | `100` | Buildings, urban canyons |
| Very poor (sparse waypoints) | `200` | Infrequent GPS, large gaps |

---

## 2. OSRM Nearest - For Single Points

**Best for:** Snapping a single coordinate to the nearest road (e.g., search result, user click).

### Example

```javascript
async function snapToRoad(lon, lat, numResults = 1) {
  const response = await fetch(
    `http://localhost:8000/osrm/nearest/v1/driving/${lon},${lat}?number=${numResults}`
  );
  const data = await response.json();

  if (data.code === 'Ok') {
    return data.waypoints.map(wp => ({
      coordinates: wp.location,
      roadName: wp.name,
      distanceFromInput: wp.distance
    }));
  }
  throw new Error('Snapping failed');
}

// Usage
const snapped = await snapToRoad(7.419, 43.733, 3);
console.log('Top 3 nearest roads:', snapped);
```

### Test It Now

```bash
# Get nearest road
curl "http://localhost:8000/osrm/nearest/v1/driving/7.419,43.733?number=1" | jq

# Get 3 nearest roads
curl "http://localhost:8000/osrm/nearest/v1/driving/7.419,43.733?number=3" | jq '.waypoints[] | {name, distance, location}'
```

---

## Common Parameters

### For Match Endpoint

| Parameter | Required | Example | Description |
|-----------|----------|---------|-------------|
| `radiuses` | ⚠️ **YES** | `50;50;50` | Search radius per point (meters) |
| `overview` | No | `full` | Route geometry: `full`, `simplified`, `false` |
| `geometries` | No | `geojson` | Format: `geojson`, `polyline`, `polyline6` |
| `timestamps` | No | `123;456;789` | Unix timestamps (improves accuracy) |
| `gaps` | No | `split` | Gap handling: `split`, `ignore` |
| `annotations` | No | `true` | Include speed, duration per segment |

### For Nearest Endpoint

| Parameter | Required | Example | Description |
|-----------|----------|---------|-------------|
| `number` | No | `3` | Number of nearest roads (default: 1, max: 100) |
| `radiuses` | No | `50` | Max search radius (meters) |
| `bearings` | No | `45,10` | Filter by direction (bearing±range) |

---

## Handling Poor GPS Quality

```javascript
async function robustMatch(coordinates, gpsQuality = 'good') {
  const qualitySettings = {
    'high': { radius: 10, gaps: 'split' },
    'good': { radius: 50, gaps: 'split' },
    'poor': { radius: 100, gaps: 'ignore' },
    'very-poor': { radius: 200, gaps: 'ignore' }
  };

  const settings = qualitySettings[gpsQuality];
  const coords = coordinates.map(c => `${c[0]},${c[1]}`).join(';');
  const radiuses = coordinates.map(() => settings.radius).join(';');

  const url = `http://localhost:8000/osrm/match/v1/driving/${coords}?` +
              `radiuses=${radiuses}&gaps=${settings.gaps}&` +
              `overview=full&geometries=geojson`;

  const response = await fetch(url);
  const data = await response.json();

  if (data.code !== 'Ok') {
    // Try again with more permissive settings
    if (gpsQuality !== 'very-poor') {
      const nextQuality = {
        'high': 'good',
        'good': 'poor',
        'poor': 'very-poor'
      }[gpsQuality];
      return robustMatch(coordinates, nextQuality);
    }
    throw new Error('Could not match trace even with permissive settings');
  }

  return data;
}
```

---

## Error Handling

### NoMatch Error
```json
{"code": "NoMatch", "message": "Could not match the trace."}
```
**Solution:** Increase `radiuses` parameter. Start with 50m, try 100m if still fails.

### NoSegment Error
```json
{"code": "NoSegment"}
```
**Solution:**
- Points too far apart - add intermediate points
- Use `gaps=split` to allow disconnected segments
- Verify coordinates are in the loaded region (Monaco)

### InvalidUrl Error
**Solution:**
- Check coordinate format: `lon,lat` (not `lat,lon`)
- Separate coordinates with semicolons: `coord1;coord2;coord3`
- No spaces in URL

---

## Performance Tips

1. **Batch requests:** Process 50-100 points per request (max 1000)
2. **Use appropriate radiuses:** Tighter = faster
3. **Include timestamps:** Improves accuracy without performance cost
4. **Cache results:** GPS coordinates don't change
5. **Parallel requests:** Process multiple trips simultaneously

---

## API Documentation

- [OSRM Match API Reference](http://project-osrm.org/docs/v5.24.0/api/#match-service)
- [OSRM Nearest API Reference](http://project-osrm.org/docs/v5.24.0/api/#nearest-service)
- [OSRM_MATCH_QUICK_FIX.md](./OSRM_MATCH_QUICK_FIX.md) - Troubleshooting guide

---

## Summary

✅ **For GPS trips:** Use OSRM Match with `radiuses=50;50;50...`
✅ **For single points:** Use OSRM Nearest
✅ **Always include radiuses:** Default 5m is too small
✅ **Include timestamps:** When available
✅ **Handle errors gracefully:** Retry with larger radius

**Your working URL template:**
```
http://localhost:8000/osrm/match/v1/driving/{coords}?radiuses=50;50;50&overview=full&geometries=geojson
```
