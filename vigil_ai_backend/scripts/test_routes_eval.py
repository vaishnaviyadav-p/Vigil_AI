import math
import json
import urllib.request
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.models import SafetyZone, Incident
from app.utils import haversine_distance

def compute_perpendicular_waypoint(start_lat, start_lon, dest_lat, dest_lon, hazard_lat, hazard_lon, buffer_m=500, side='away'):
    # Meters conversion factors
    m_per_deg_lat = 110540.0
    m_per_deg_lon = 111320.0 * math.cos(math.radians(start_lat))
    
    dx = (dest_lon - start_lon) * m_per_deg_lon
    dy = (dest_lat - start_lat) * m_per_deg_lat
    d_len = math.hypot(dx, dy)
    if d_len == 0:
        return dest_lat, dest_lon
    
    ux, uy = dx / d_len, dy / d_len
    px, py = -uy, ux  # perpendicular normal
    
    hx = (hazard_lon - start_lon) * m_per_deg_lon
    hy = (hazard_lat - start_lat) * m_per_deg_lat
    
    proj = max(d_len * 0.15, min(d_len * 0.85, hx * ux + hy * uy))
    
    bx = start_lon + (ux * proj) / m_per_deg_lon
    by = start_lat + (uy * proj) / m_per_deg_lat
    
    dist_perp = hx * px + hy * py
    sign = -1.0 if dist_perp >= 0 else 1.0
    if side == 'toward':
        sign = -sign
    
    detour_lon = bx + (sign * px * buffer_m) / m_per_deg_lon
    detour_lat = by + (sign * py * buffer_m) / m_per_deg_lat
    return detour_lat, detour_lon

def fetch_osrm_path(start_lat, start_lon, dest_lat, dest_lon, waypoints=None, mode='foot'):
    points_str = f"{start_lon:.6f},{start_lat:.6f}"
    if waypoints:
        for wp in waypoints:
            points_str += f";{wp['lon']:.6f},{wp['lat']:.6f}"
    points_str += f";{dest_lon:.6f},{dest_lat:.6f}"
    
    url = f"https://router.project-osrm.org/route/v1/{mode}/{points_str}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode())
            if data.get('code') == 'Ok' and data.get('routes'):
                r = data['routes'][0]
                coords = [[p[1], p[0]] for p in r['geometry']['coordinates']]
                return {
                    'coordinates': coords,
                    'distance_m': r['distance'],
                    'duration_s': r['duration'],
                    'is_fallback': False
                }
    except Exception as e:
        print(f"OSRM query failed ({e}), using geometric fallback.")
    
    # Fallback interpolation
    steps = 25
    coords = []
    if waypoints:
        all_pts = [(start_lat, start_lon)] + [(w['lat'], w['lon']) for w in waypoints] + [(dest_lat, dest_lon)]
        for i in range(len(all_pts) - 1):
            p1 = all_pts[i]
            p2 = all_pts[i+1]
            seg_steps = steps // (len(all_pts) - 1)
            for s in range(seg_steps):
                t = s / float(seg_steps)
                coords.append([p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t])
        coords.append([dest_lat, dest_lon])
    else:
        for s in range(steps + 1):
            t = s / float(steps)
            coords.append([start_lat + (dest_lat - start_lat) * t, start_lon + (dest_lon - start_lon) * t])
            
    dist_m = haversine_distance(start_lat, start_lon, dest_lat, dest_lon)
    if waypoints:
        dist_m *= 1.25
    dur_s = (dist_m / 1.2)
    return {
        'coordinates': coords,
        'distance_m': dist_m,
        'duration_s': dur_s,
        'is_fallback': True
    }

def evaluate_route_safety(coords, zones, incidents):
    score = 100.0
    hazards_intersected = []
    incidents_nearby = []
    safe_zones_covered = []
    
    for z in zones:
        min_d = min(haversine_distance(p[0], p[1], z.latitude, z.longitude) for p in coords)
        if min_d <= z.radius_meters:
            if z.zone_type == 'HIGH_RISK':
                score -= 35
                hazards_intersected.append({
                    'id': z.id,
                    'name': z.name,
                    'zone_type': z.zone_type,
                    'distance_meters': round(min_d, 1),
                    'radius_meters': z.radius_meters
                })
            elif z.zone_type == 'CAUTION':
                score -= 15
                hazards_intersected.append({
                    'id': z.id,
                    'name': z.name,
                    'zone_type': z.zone_type,
                    'distance_meters': round(min_d, 1),
                    'radius_meters': z.radius_meters
                })
            elif z.zone_type == 'SAFE':
                score = min(100, score + 10)
                safe_zones_covered.append({
                    'id': z.id,
                    'name': z.name,
                    'distance_meters': round(min_d, 1)
                })
        elif z.zone_type == 'SAFE' and min_d <= 200:
            score = min(100, score + 5)
            safe_zones_covered.append({
                'id': z.id,
                'name': z.name,
                'distance_meters': round(min_d, 1)
            })
            
    for inc in incidents:
        min_d = min(haversine_distance(p[0], p[1], inc.latitude, inc.longitude) for p in coords)
        if min_d <= 200:
            penalty = 20 if inc.severity == 'CRITICAL' else (12 if inc.severity == 'HIGH' else 6)
            score -= penalty
            incidents_nearby.append({
                'id': inc.id,
                'category': inc.category,
                'severity': inc.severity,
                'distance_meters': round(min_d, 1)
            })
            
    score = max(5.0, min(100.0, score))
    risk_level = 'SAFE' if score >= 80 else ('MODERATE' if score >= 60 else 'HIGH_RISK')
    
    return {
        'safety_score': round(score),
        'risk_level': risk_level,
        'hazards_intersected': hazards_intersected,
        'incidents_nearby': incidents_nearby,
        'safe_zones_covered': safe_zones_covered
    }

if __name__ == '__main__':
    app = create_app()
    with app.app_context():
        zones = SafetyZone.query.filter_by(is_active=True).all()
        incidents = Incident.query.all()
        
        start_lat, start_lon = 12.9716, 77.5946
        dest_lat, dest_lon = 12.9850, 77.6100
        
        # 1. Direct path
        direct = fetch_osrm_path(start_lat, start_lon, dest_lat, dest_lon)
        direct_eval = evaluate_route_safety(direct['coordinates'], zones, incidents)
        
        print(f"Direct Route: Score={direct_eval['safety_score']}, Risk={direct_eval['risk_level']}, Dist={direct['distance_m']/1000:.2f}km")
        print(f"  Hazards: {[h['name'] for h in direct_eval['hazards_intersected']]}")
        print(f"  Incidents: {[i['category'] + ' (' + i['severity'] + ')' for i in direct_eval['incidents_nearby']]}")
        
        # 2. Try candidate detour waypoints
        print("\nTesting candidate waypoints for safe route detour:")
        candidates = [
            (12.9720, 77.6050, "South-East Commercial Arterial"),
            (12.9750, 77.6120, "East Trunk Road bypass"),
            (12.9700, 77.6010, "Cubbon Road South Bypass"),
            (12.9780, 77.6110, "Ulsoor Road Safe Corridor"),
        ]
        best_route = direct
        best_eval = direct_eval
        best_wp_name = "Direct"
        
        for lat, lon, label in candidates:
            r = fetch_osrm_path(start_lat, start_lon, dest_lat, dest_lon, waypoints=[{'lat': lat, 'lon': lon}])
            ev = evaluate_route_safety(r['coordinates'], zones, incidents)
            print(f"  {label} ({lat}, {lon}): Score={ev['safety_score']}, Dist={r['distance_m']/1000:.2f}km, Hazards={[h['name'] for h in ev['hazards_intersected']]}, Incidents={[i['category'] for i in ev['incidents_nearby']]}")
            if ev['safety_score'] > best_eval['safety_score']:
                best_score = ev['safety_score']
                best_route = r
                best_eval = ev
                best_wp_name = label
                
        print(f"\nWinning Safe Route: {best_wp_name} with Score {best_eval['safety_score']} (Direct was {direct_eval['safety_score']})")
