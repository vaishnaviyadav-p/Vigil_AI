import urllib.request
import json
import math
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.models import SafetyZone, Incident
from app.utils import haversine_distance

def test_dual_mode_routing():
    start_lat, start_lon = 12.9716, 77.5946
    dest_lat, dest_lon = 12.9850, 77.6100
    detour_lat, detour_lon = 12.9700, 77.6010

    # 1. Test direct foot vs driving
    coords_direct = f"{start_lon:.6f},{start_lat:.6f};{dest_lon:.6f},{dest_lat:.6f}"
    coords_detour = f"{start_lon:.6f},{start_lat:.6f};{detour_lon:.6f},{detour_lat:.6f};{dest_lon:.6f},{dest_lat:.6f}"

    for mode in ['foot', 'car']:
        url = f"https://routing.openstreetmap.de/routed-{mode}/route/v1/driving/{coords_direct}?overview=full&geometries=geojson"
        req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
        with urllib.request.urlopen(req, timeout=5) as r:
            d = json.loads(r.read().decode())['routes'][0]
            print(f"Direct {mode.upper()}: {d['distance']/1000:.2f}km, {d['duration']/60:.1f} mins")

    for mode in ['foot', 'car']:
        url = f"https://routing.openstreetmap.de/routed-{mode}/route/v1/driving/{coords_detour}?overview=full&geometries=geojson"
        req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
        with urllib.request.urlopen(req, timeout=5) as r:
            d = json.loads(r.read().decode())['routes'][0]
            print(f"Detour {mode.upper()}: {d['distance']/1000:.2f}km, {d['duration']/60:.1f} mins")

if __name__ == '__main__':
    test_dual_mode_routing()
