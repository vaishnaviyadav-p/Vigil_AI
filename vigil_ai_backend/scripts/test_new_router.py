import math
import json
import urllib.request
import urllib.parse
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from app.utils import haversine_distance

def fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=None, mode='foot'):
    points_str = f"{start_lon:.6f},{start_lat:.6f}"
    if waypoints:
        for wp in waypoints:
            points_str += f";{wp['lon']:.6f},{wp['lat']:.6f}"
    points_str += f";{dest_lon:.6f},{dest_lat:.6f}"
    
    is_driving = mode in ['driving', 'car']
    routed_subdomain = 'routed-car' if is_driving else 'routed-foot'
    
    # Try OpenStreetMap dedicated routed profile
    urls = [
        f"https://routing.openstreetmap.de/{routed_subdomain}/route/v1/driving/{points_str}?overview=full&geometries=geojson",
        f"https://router.project-osrm.org/route/v1/{'driving' if is_driving else 'foot'}/{points_str}?overview=full&geometries=geojson"
    ]
    
    for url in urls:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                data = json.loads(resp.read().decode())
                if data.get('code') == 'Ok' and data.get('routes'):
                    r = data['routes'][0]
                    coords = [[p[1], p[0]] for p in r['geometry']['coordinates']]
                    duration = float(r['duration'])
                    
                    # If project-osrm fallback was used for foot, adjust duration to walking pace (1.25 m/s)
                    if not is_driving and 'project-osrm.org' in url:
                        duration = float(r['distance']) / 1.25
                        
                    return {
                        'coordinates': coords,
                        'distance_m': float(r['distance']),
                        'duration_s': duration,
                        'is_fallback': False,
                        'is_available': True,
                        'mode': 'driving' if is_driving else 'foot'
                    }
        except Exception:
            continue
            
    # Fallback to direct linear interpolation with real Haversine distance
    steps = 30
    coords = []
    if waypoints:
        all_pts = [(start_lat, start_lon)] + [(w['lat'], w['lon']) for w in waypoints] + [(dest_lat, dest_lon)]
        total_dist = 0.0
        for i in range(len(all_pts) - 1):
            p1 = all_pts[i]
            p2 = all_pts[i+1]
            total_dist += haversine_distance(p1[0], p1[1], p2[0], p2[1])
            seg_steps = max(5, steps // (len(all_pts) - 1))
            for s in range(seg_steps):
                t = s / float(seg_steps)
                coords.append([p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t])
        coords.append([dest_lat, dest_lon])
        dist_m = total_dist
    else:
        for s in range(steps + 1):
            t = s / float(steps)
            coords.append([start_lat + (dest_lat - start_lat) * t, start_lon + (dest_lon - start_lon) * t])
        dist_m = haversine_distance(start_lat, start_lon, dest_lat, dest_lon)
        
    speed_ms = 9.7 if is_driving else 1.2
    dur_s = dist_m / speed_ms
    return {
        'coordinates': coords,
        'distance_m': dist_m,
        'duration_s': dur_s,
        'is_fallback': True,
        'is_available': True,
        'mode': 'driving' if is_driving else 'foot'
    }

print('Testing foot and car in script...')
r_foot = fetch_osrm_route(12.9716, 77.5946, 12.9850, 77.6100, mode='foot')
r_car = fetch_osrm_route(12.9716, 77.5946, 12.9850, 77.6100, mode='driving')
print(f"Foot: {r_foot['distance_m']}m, {r_foot['duration_s']}s ({r_foot['duration_s']/60:.1f} mins), points: {len(r_foot['coordinates'])}")
print(f"Car: {r_car['distance_m']}m, {r_car['duration_s']}s ({r_car['duration_s']/60:.1f} mins), points: {len(r_car['coordinates'])}")
