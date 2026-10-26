import sys
import os
import json
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.utils import haversine_distance
from app.services.route_service import fetch_osrm_route, evaluate_route_safety, compute_perpendicular_waypoint
from app.models import SafetyZone, Incident
from app import create_app

app = create_app()
with app.app_context():
    zones = SafetyZone.query.filter_by(is_active=True).all()
    incidents = Incident.query.all()
    
    start_lat, start_lon = 12.9716, 77.5946
    dest_lat, dest_lon = 12.9850, 77.6100
    
    t0 = time.time()
    # 1. Fetch direct foot & car
    direct_foot = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, mode='foot')
    direct_car = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, mode='driving')
    
    direct_eval_foot = evaluate_route_safety(direct_foot['coordinates'], zones, incidents)
    direct_eval_car = evaluate_route_safety(direct_car['coordinates'], zones, incidents)
    
    print(f"Direct Foot: {direct_foot['distance_m']/1000:.2f}km, {direct_foot['duration_s']/60:.1f}m, score={direct_eval_foot['safety_score']}")
    print(f"Direct Car: {direct_car['distance_m']/1000:.2f}km, {direct_car['duration_s']/60:.1f}m, score={direct_eval_car['safety_score']}")
    
    # 2. Detour candidates
    candidate_wps = []
    if direct_eval_foot['hazards_intersected']:
        primary_hazard = direct_eval_foot['hazards_intersected'][0]
        hz = next((z for z in zones if z.id == primary_hazard['id']), None)
        if hz:
            for buf in [500, 800]:
                for side in ['away', 'toward']:
                    wlat, wlon = compute_perpendicular_waypoint(start_lat, start_lon, dest_lat, dest_lon, hz.latitude, hz.longitude, buffer_m=buf, side=side)
                    candidate_wps.append({'lat': wlat, 'lon': wlon})
                    
    # Pick best candidate for foot
    best_wp = None
    best_score = direct_eval_foot['safety_score']
    best_foot = direct_foot
    best_eval = direct_eval_foot
    
    for wp in candidate_wps:
        r = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=[wp], mode='foot')
        ev = evaluate_route_safety(r['coordinates'], zones, incidents)
        if ev['safety_score'] > best_score:
            best_score = ev['safety_score']
            best_wp = wp
            best_foot = r
            best_eval = ev
            
    print(f"Best Safe Foot: {best_foot['distance_m']/1000:.2f}km, {best_foot['duration_s']/60:.1f}m, score={best_eval['safety_score']}")
    
    # Apply winning waypoint to car
    if best_wp:
        safe_car = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=[best_wp], mode='driving')
        safe_eval_car = evaluate_route_safety(safe_car['coordinates'], zones, incidents)
    else:
        safe_car = direct_car
        safe_eval_car = direct_eval_car
        
    print(f"Best Safe Car: {safe_car['distance_m']/1000:.2f}km, {safe_car['duration_s']/60:.1f}m, score={safe_eval_car['safety_score']}")
    print(f"Total time taken: {time.time() - t0:.2f} seconds")
