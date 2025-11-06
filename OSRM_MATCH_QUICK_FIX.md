# OSRM Match - Quick Fix for "NoMatch" Error

## ⚠️ Problem

Getting this error?
```json
{
  "message": "Could not match the trace.",
  "code": "NoMatch"
}
```

## ✅ Solution

**Add the `radiuses` parameter!**

OSRM's default search radius is only **5 meters**. If your GPS coordinates are further from roads, you must specify a larger radius.

---

## Working Examples

### ❌ FAILS - No radiuses parameter
```bash
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734?overview=full&geometries=geojson"
```
**Error:** `"NoMatch"`

### ✅ WORKS - With radiuses=50 (50 meters)
```bash
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734?overview=full&geometries=geojson&radiuses=50;50;50"
```
**Success!**

### ✅ WORKS - With larger radius for poor GPS
```bash
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734?overview=full&geometries=geojson&radiuses=100;100;100"
```
**Success!**

---

## Choosing the Right Radius

| GPS Quality | Recommended Radius | Use Case |
|-------------|-------------------|----------|
| **High-quality** (vehicle tracker) | `10` | Precise vehicle GPS |
| **Good** (phone outdoors) | `50` | Mobile phone in open area |
| **Poor** (phone urban/indoor) | `100-200` | Urban canyons, buildings |
| **Very poor** (sparse waypoints) | `500` | Infrequent GPS pings |

### Rule of Thumb
- **Start with 50m** - works for most cases
- **Use 100m+** - for noisy/sparse data
- **Use 10m** - only for high-precision GPS

---

## JavaScript Helper Function

```javascript
async function matchGPSTrace(coordinates, gpsQuality = 'good') {
  // Choose radius based on GPS quality
  const radiusMap = {
    'high': 10,
    'good': 50,
    'poor': 100,
    'very-poor': 200
  };

  const radius = radiusMap[gpsQuality] || 50;
  const radiuses = coordinates.map(() => radius).join(';');

  const coords = coordinates.map(c => `${c[0]},${c[1]}`).join(';');
  const url = `http://localhost:8000/osrm/match/v1/driving/${coords}?` +
              `overview=full&geometries=geojson&radiuses=${radiuses}`;

  const response = await fetch(url);
  const data = await response.json();

  if (data.code !== 'Ok') {
    throw new Error(`Match failed: ${data.message || data.code}`);
  }

  return {
    snappedPoints: data.tracepoints.map(tp => ({
      location: tp.location,
      roadName: tp.name,
      distanceFromOriginal: tp.distance
    })),
    routeGeometry: data.matchings[0].geometry.coordinates,
    distance: data.matchings[0].distance,
    duration: data.matchings[0].duration,
    confidence: data.matchings[0].confidence
  };
}

// Usage
const trip = [
  [7.419, 43.733],
  [7.4195, 43.7335],
  [7.420, 43.734]
];

// For phone GPS
const result = await matchGPSTrace(trip, 'good');

// For poor GPS
const noisyResult = await matchGPSTrace(trip, 'poor');
```

---

## Variable Radius Per Point

You can set different radius for each point:

```bash
# Point 1: 100m, Point 2: 50m, Point 3: 200m
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.420,43.734;7.421,43.735?radiuses=100;50;200"
```

**Use case:** First/last points might be more uncertain (starting GPS fix, stopping movement).

---

## Understanding the Distance Values

From your trace, here's how far each point was from roads:

```javascript
// Your test coordinates
const testResult = await matchGPSTrace([
  [7.419, 43.733],   // 70.4m from road ❌ (> 5m default)
  [7.4195, 43.7335], // 23.0m from road ❌
  [7.420, 43.734],   // 3.5m from road  ✅ (would work with default)
  [7.4205, 43.7345], // 17.4m from road ❌
  [7.421, 43.735]    // 41.7m from road ❌
]);

// With radiuses=50, all points match! ✅
```

---

## Common Errors and Fixes

### Error: "NoMatch"
**Cause:** Radius too small
**Fix:** Increase `radiuses` parameter

### Error: "NoSegment"
**Cause:** Points too far apart or can't be connected
**Fix:**
- Add more intermediate points
- Use `gaps=split` parameter
- Check coordinates are in correct region

### Error: "InvalidUrl"
**Cause:** Malformed URL or coordinates
**Fix:**
- Coordinates must be `lon,lat` format
- Separate coordinates with semicolons: `lon1,lat1;lon2,lat2`
- No spaces in URL

---

## Complete Working Example

```bash
# Full example with all best practices
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734;7.4205,43.7345;7.421,43.735?overview=full&geometries=geojson&radiuses=50;50;50;50;50&annotations=true&steps=false&gaps=ignore" | jq

# Returns:
# - Snapped coordinates for each point
# - Connected route geometry
# - Distance (295.2m)
# - Duration (60.1s)
# - Confidence (0.546)
```

---

## Quick Reference

### Minimum Required
```
/osrm/match/v1/driving/{coords}?radiuses=50;50;50
```

### Recommended for Production
```
/osrm/match/v1/driving/{coords}
  ?overview=full
  &geometries=geojson
  &radiuses=50;50;50
  &annotations=true
  &gaps=split
```

### With Timestamps (Most Accurate)
```
/osrm/match/v1/driving/{coords}
  ?radiuses=50;50;50
  &timestamps=1234567890;1234567895;1234567900
```

---

## Pro Tips

1. **Always include radiuses** - Don't rely on the 5m default
2. **Use timestamps** - Improves accuracy significantly
3. **Check distance values** - `tracepoints[].distance` tells you how far each point was from a road
4. **Match in batches** - Don't exceed 1000 points per request (configurable)
5. **Handle errors gracefully** - Some traces might not match well

---

## Testing Your Setup

```bash
# Test 1: Simple match with 50m radius
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.421,43.735?radiuses=50;50"

# Test 2: Your original failing example (now fixed)
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734;7.4205,43.7345;7.421,43.735?overview=full&geometries=geojson&radiuses=50;50;50;50;50"

# Test 3: Check how far your points are from roads
curl "http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.421,43.735?radiuses=100;100" | jq '.tracepoints[].distance'
```

---

## Summary

✅ **Always add `radiuses` parameter**
✅ **Use 50m as default for phone GPS**
✅ **Use 100m+ for poor quality GPS**
✅ **Check `distance` values to understand GPS accuracy**
✅ **Add timestamps when available**

**Your working URL:**
```
http://localhost:8000/osrm/match/v1/driving/7.419,43.733;7.4195,43.7335;7.420,43.734;7.4205,43.7345;7.421,43.735?overview=full&geometries=geojson&radiuses=50;50;50;50;50
```
