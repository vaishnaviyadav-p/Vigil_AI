import urllib.request
import json

# Test longer distance or complex city grid in Bangalore
# Start: MG Road (12.9753, 77.6065), Dest: Koramangala (12.9352, 77.6245)
coords = '77.606500,12.975300;77.624500,12.935200'
for mode in ['foot', 'driving', 'car']:
    url = f'https://router.project-osrm.org/route/v1/{mode}/{coords}?overview=full&geometries=geojson'
    req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            if data.get('code') == 'Ok':
                r = data['routes'][0]
                print(f'Mode: {mode.upper()}')
                print(f"  Distance: {r['distance']} m ({r['distance']/1000:.2f} km)")
                print(f"  Duration: {r['duration']} s ({r['duration']/60:.1f} mins)")
                print(f"  Points: {len(r['geometry']['coordinates'])}")
            else:
                print(f'Mode: {mode} code: {data.get("code")}')
    except Exception as e:
        print(f'Mode: {mode} failed: {e}')
