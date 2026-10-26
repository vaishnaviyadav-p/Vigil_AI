import urllib.request
import json

coords = '77.594600,12.971600;77.601000,12.970000;77.610000,12.985000'
for mode in ['foot', 'car']:
    url = f'https://routing.openstreetmap.de/routed-{mode}/route/v1/driving/{coords}?overview=full&geometries=geojson'
    req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            r = data['routes'][0]
            print(f'{mode.upper()} with detour:')
            print(f"  Distance: {r['distance']} m ({r['distance']/1000:.2f} km)")
            print(f"  Duration: {r['duration']} s ({r['duration']/60:.1f} mins)")
            print(f"  Points: {len(r['geometry']['coordinates'])}")
    except Exception as e:
        print(f'{mode} failed: {e}')
