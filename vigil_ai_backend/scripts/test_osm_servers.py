import urllib.request
import json

coords = '77.606500,12.975300;77.624500,12.935200'
servers = [
    ('OSM DE Foot', f'https://routing.openstreetmap.de/routed-foot/route/v1/driving/{coords}?overview=full&geometries=geojson'),
    ('OSM DE Car', f'https://routing.openstreetmap.de/routed-car/route/v1/driving/{coords}?overview=full&geometries=geojson'),
    ('OSM DE Bike', f'https://routing.openstreetmap.de/routed-bike/route/v1/driving/{coords}?overview=full&geometries=geojson'),
]

for name, url in servers:
    req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            r = data['routes'][0]
            print(f'{name}:')
            print(f"  Distance: {r['distance']} m ({r['distance']/1000:.2f} km)")
            print(f"  Duration: {r['duration']} s ({r['duration']/60:.1f} mins)")
            print(f"  Points: {len(r['geometry']['coordinates'])}")
    except Exception as e:
        print(f'{name} failed: {e}')
