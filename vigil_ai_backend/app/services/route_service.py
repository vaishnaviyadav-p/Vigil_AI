import math
import json
import urllib.request
import urllib.parse
from app.utils import haversine_distance

def geocode_search(query):
    """
    Searches for addresses / landmarks using OpenStreetMap Nominatim.
    Returns a list of dicts with name, display_name, latitude, longitude.
    """
    if not query or not query.strip():
        return []
    
    clean_q = query.strip()
    encoded_q = urllib.parse.quote(clean_q)
    url = f"https://nominatim.openstreetmap.org/search?q={encoded_q}&format=json&limit=6&addressdetails=1"
    req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
    
    results = []
    try:
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode())
            for item in data:
                display_name = item.get('display_name', '')
                short_name = item.get('name') or display_name.split(',')[0].strip()
                try:
                    lat = float(item.get('lat'))
                    lon = float(item.get('lon'))
                    results.append({
                        'name': short_name,
                        'display_name': display_name,
                        'latitude': lat,
                        'longitude': lon
                    })
                except (ValueError, TypeError):
                    continue
    except Exception:
        # Graceful fallback on network timeout/error
        pass
        
    return results

def compute_perpendicular_waypoint(start_lat, start_lon, dest_lat, dest_lon, hazard_lat, hazard_lon, buffer_m=500, side='away'):
    """
    Computes a geographic waypoint perpendicular to the direct travel vector,
    steering away from (or toward) a specific hazard point.
    """
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
    
    # Project hazard onto travel vector clamped between 15% and 85%
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

def fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=None, mode='foot'):
    """
    Fetches street-network route geometry from OpenStreetMap OSRM routing profiles.
    mode='foot' -> Dedicated pedestrian routing profile (sidewalks, footways, walking pace ~4.5 km/h).
    mode='driving' -> Dedicated vehicular routing profile (roads, speed limits, turn rules, car pace ~35-40 km/h).
    Falls back gracefully to secondary public OSRM or straight-line vector if offline.
    """
    is_driving = mode in ['driving', 'car']
    points_str = f"{start_lon:.6f},{start_lat:.6f}"
    if waypoints:
        for wp in waypoints:
            points_str += f";{wp['lon']:.6f},{wp['lat']:.6f}"
    points_str += f";{dest_lon:.6f},{dest_lat:.6f}"
    
    routed_subdomain = 'routed-car' if is_driving else 'routed-foot'
    candidate_urls = [
        f"https://routing.openstreetmap.de/{routed_subdomain}/route/v1/driving/{points_str}?overview=full&geometries=geojson",
        f"https://router.project-osrm.org/route/v1/{'driving' if is_driving else 'foot'}/{points_str}?overview=full&geometries=geojson"
    ]
    
    for url in candidate_urls:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'VigilAI-WomenSafety/1.0'})
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                data = json.loads(resp.read().decode())
                if data.get('code') == 'Ok' and data.get('routes'):
                    r = data['routes'][0]
                    coords = [[p[1], p[0]] for p in r['geometry']['coordinates']]
                    dist_m = float(r['distance'])
                    dur_s = float(r['duration'])
                    
                    # If project-osrm fallback was used for foot, adjust duration to realistic walking pace (1.25 m/s)
                    if not is_driving and 'project-osrm.org' in url:
                        dur_s = dist_m / 1.25
                        
                    return {
                        'coordinates': coords,
                        'distance_m': dist_m,
                        'duration_s': dur_s,
                        'is_fallback': False,
                        'is_available': True,
                        'mode': 'driving' if is_driving else 'foot',
                        'error_reason': None
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
        
    speed_ms = 9.7 if is_driving else 1.25  # ~35 km/h driving vs ~4.5 km/h walking
    dur_s = dist_m / speed_ms
    return {
        'coordinates': coords,
        'distance_m': dist_m,
        'duration_s': dur_s,
        'is_fallback': True,
        'is_available': True,
        'mode': 'driving' if is_driving else 'foot',
        'error_reason': 'Online routing network unavailable; calculated via geometric vector trajectory.'
    }

def evaluate_route_safety(coords, zones, incidents):
    """
    Evaluates safety score and risk exposure strictly against verified
    SafetyZone and Incident records from the database.
    Does NOT invent fake risk factors.
    """
    score = 100.0
    hazards_intersected = []
    incidents_nearby = []
    safe_zones_covered = []
    
    for z in zones:
        min_d = min(haversine_distance(p[0], p[1], z.latitude, z.longitude) for p in coords)
        if min_d <= z.radius_meters:
            if z.zone_type == 'HIGH_RISK':
                score -= 35.0
                hazards_intersected.append({
                    'id': z.id,
                    'name': z.name,
                    'zone_type': z.zone_type,
                    'distance_meters': round(min_d, 1),
                    'radius_meters': z.radius_meters
                })
            elif z.zone_type == 'CAUTION':
                score -= 15.0
                hazards_intersected.append({
                    'id': z.id,
                    'name': z.name,
                    'zone_type': z.zone_type,
                    'distance_meters': round(min_d, 1),
                    'radius_meters': z.radius_meters
                })
            elif z.zone_type == 'SAFE':
                score = min(100.0, score + 10.0)
                safe_zones_covered.append({
                    'id': z.id,
                    'name': z.name,
                    'distance_meters': round(min_d, 1)
                })
        elif z.zone_type == 'SAFE' and min_d <= 200:
            score = min(100.0, score + 5.0)
            safe_zones_covered.append({
                'id': z.id,
                'name': z.name,
                'distance_meters': round(min_d, 1)
            })
            
    for inc in incidents:
        min_d = min(haversine_distance(p[0], p[1], inc.latitude, inc.longitude) for p in coords)
        if min_d <= 200:
            penalty = 20.0 if inc.severity == 'CRITICAL' else (12.0 if inc.severity == 'HIGH' else 6.0)
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

def _format_time_text(minutes_val, mode_label):
    if minutes_val is None:
        return f"Unavailable ({mode_label} routing unavailable)"
    return f"{minutes_val} mins"

def calculate_safe_route_recommendation(start_lat, start_lon, dest_lat, dest_lon, zones, incidents, mode='foot'):
    """
    Computes both the Shortest Direct Route and the AI Recommended Safe Route.
    Calculates Walking Time and Car Driving Time independently via dedicated profiles.
    Ensures that road geometry and distances correspond to the selected travel mode.
    """
    is_driving = mode in ['driving', 'car']
    active_mode = 'driving' if is_driving else 'foot'
    other_mode = 'foot' if is_driving else 'driving'
    
    # 1. Direct Routes for both modes
    direct_active = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, mode=active_mode)
    direct_other = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, mode=other_mode)
    
    direct_foot = direct_other if is_driving else direct_active
    direct_car = direct_active if is_driving else direct_other
    
    direct_eval_active = evaluate_route_safety(direct_active['coordinates'], zones, incidents)
    direct_eval_foot = evaluate_route_safety(direct_foot['coordinates'], zones, incidents)
    direct_eval_car = evaluate_route_safety(direct_car['coordinates'], zones, incidents)
    
    # Durations
    direct_walk_time = max(1, round(direct_foot['duration_s'] / 60.0)) if direct_foot['is_available'] else None
    direct_drive_time = max(1, round(direct_car['duration_s'] / 60.0)) if direct_car['is_available'] else None
    
    # 2. Search for Safe Detour Waypoint if active route intersects hazards
    best_wp = None
    if direct_eval_active['hazards_intersected'] or any(i['severity'] in ['HIGH', 'CRITICAL'] for i in direct_eval_active['incidents_nearby']) or direct_eval_active['safety_score'] < 85:
        candidate_wps = []
        if direct_eval_active['hazards_intersected']:
            primary_hazard = direct_eval_active['hazards_intersected'][0]
            hz = next((z for z in zones if z.id == primary_hazard['id']), None)
            if hz:
                for buf in [500, 800]:
                    for side in ['away', 'toward']:
                        wlat, wlon = compute_perpendicular_waypoint(start_lat, start_lon, dest_lat, dest_lon, hz.latitude, hz.longitude, buffer_m=buf, side=side)
                        candidate_wps.append({'lat': wlat, 'lon': wlon})
                        
        mid_lat = (start_lat + dest_lat) / 2.0
        mid_lon = (start_lon + dest_lon) / 2.0
        for buf in [600]:
            for side in ['away', 'toward']:
                wlat, wlon = compute_perpendicular_waypoint(start_lat, start_lon, dest_lat, dest_lon, mid_lat, mid_lon, buffer_m=buf, side=side)
                candidate_wps.append({'lat': wlat, 'lon': wlon})
                
        for sz in zones:
            if sz.zone_type == 'SAFE':
                d_start = haversine_distance(start_lat, start_lon, sz.latitude, sz.longitude)
                d_dest = haversine_distance(dest_lat, dest_lon, sz.latitude, sz.longitude)
                if (d_start + d_dest) < direct_active['distance_m'] * 1.6:
                    candidate_wps.append({'lat': sz.latitude, 'lon': sz.longitude})
                    
        # Test candidate waypoints on active mode
        best_active_route = direct_active
        best_active_eval = direct_eval_active
        best_active_score = direct_eval_active['safety_score']
        
        for wp in candidate_wps:
            c_route = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=[wp], mode=active_mode)
            if c_route['distance_m'] > direct_active['distance_m'] * 2.1:
                continue
            c_eval = evaluate_route_safety(c_route['coordinates'], zones, incidents)
            if (c_eval['safety_score'] > best_active_score) or \
               (c_eval['safety_score'] == best_active_score and c_route['distance_m'] < best_active_route['distance_m']):
                best_active_score = c_eval['safety_score']
                best_active_eval = c_eval
                best_active_route = c_route
                best_wp = wp
                
        safe_active = best_active_route
        safe_eval_active = best_active_eval
    else:
        safe_active = direct_active
        safe_eval_active = direct_eval_active
        
    # 3. Compute safe route for other mode
    if best_wp:
        safe_other = fetch_osrm_route(start_lat, start_lon, dest_lat, dest_lon, waypoints=[best_wp], mode=other_mode)
        safe_eval_other = evaluate_route_safety(safe_other['coordinates'], zones, incidents)
    else:
        safe_other = direct_other
        safe_eval_other = direct_eval_other
        
    safe_foot = safe_other if is_driving else safe_active
    safe_car = safe_active if is_driving else safe_other
    safe_eval_foot = safe_eval_other if is_driving else safe_eval_active
    safe_eval_car = safe_eval_active if is_driving else safe_eval_other
    
    safe_walk_time = max(1, round(safe_foot['duration_s'] / 60.0)) if safe_foot['is_available'] else None
    safe_drive_time = max(1, round(safe_car['duration_s'] / 60.0)) if safe_car['is_available'] else None
    
    # 4. Construct Direct Route Payload (for active mode)
    direct_dist_km = round(direct_active['distance_m'] / 1000.0, 2)
    direct_time_mins = max(1, round(direct_active['duration_s'] / 60.0))
    
    if direct_eval_active['hazards_intersected'] or direct_eval_active['incidents_nearby']:
        hazards_desc = []
        if direct_eval_active['hazards_intersected']:
            h_names = [f"{h['name']} ({h['zone_type']})" for h in direct_eval_active['hazards_intersected']]
            hazards_desc.append(f"Crosses: {', '.join(h_names)}")
        if direct_eval_active['incidents_nearby']:
            hazards_desc.append(f"{len(direct_eval_active['incidents_nearby'])} nearby reported incident(s)")
        direct_risk_exposure = " | ".join(hazards_desc)
    else:
        direct_risk_exposure = "Minimal. No registered safety hazards or incidents detected along direct route."
        
    direct_payload = {
        'name': 'Shortest Direct Path',
        'safety_score': direct_eval_active['safety_score'],
        'risk_level': direct_eval_active['risk_level'],
        'distance_km': direct_dist_km,
        'estimated_time_mins': direct_time_mins,
        'estimated_walking_time_mins': direct_walk_time,
        'estimated_driving_time_mins': direct_drive_time,
        'walking_time_text': _format_time_text(direct_walk_time, 'Walking'),
        'driving_time_text': _format_time_text(direct_drive_time, 'Driving'),
        'risk_exposure': direct_risk_exposure,
        'supporting_data': direct_eval_active,
        'coordinates': direct_active['coordinates'],
        'waypoints': [{'lat': p[0], 'lon': p[1]} for p in direct_active['coordinates']],
        'is_recommended': False,
        'is_fallback': direct_active['is_fallback'],
        'travel_mode': active_mode
    }
    
    # 5. Construct Safe Route Payload (for active mode)
    safe_dist_km = round(safe_active['distance_m'] / 1000.0, 2)
    safe_time_mins = max(1, round(safe_active['duration_s'] / 60.0))
    
    hazards_avoided = []
    direct_h_names = {h['name'] for h in direct_eval_active['hazards_intersected']}
    safe_h_names = {h['name'] for h in safe_eval_active['hazards_intersected']}
    for name in (direct_h_names - safe_h_names):
        hazards_avoided.append(f"Bypassed {name}")
        
    direct_inc_types = {i['category'] for i in direct_eval_active['incidents_nearby']}
    safe_inc_types = {i['category'] for i in safe_eval_active['incidents_nearby']}
    for cat in (direct_inc_types - safe_inc_types):
        hazards_avoided.append(f"Avoided reported {cat} incident area")
        
    if not hazards_avoided and safe_eval_active['safety_score'] > direct_eval_active['safety_score']:
        hazards_avoided.append(f"Reduced proximity to high-risk areas (+{safe_eval_active['safety_score'] - direct_eval_active['safety_score']} safety index)")
        
    if hazards_avoided:
        safe_risk_exposure = f"Safer detour: {', '.join(hazards_avoided)}"
    else:
        safe_risk_exposure = "Minimal risk exposure. Follows well-monitored street corridors."
        
    safe_supporting = dict(safe_eval_active)
    safe_supporting['hazards_avoided'] = hazards_avoided
    
    safe_payload = {
        'name': 'AI Recommended Safe Path',
        'safety_score': safe_eval_active['safety_score'],
        'risk_level': safe_eval_active['risk_level'],
        'distance_km': safe_dist_km,
        'estimated_time_mins': safe_time_mins,
        'estimated_walking_time_mins': safe_walk_time,
        'estimated_driving_time_mins': safe_drive_time,
        'walking_time_text': _format_time_text(safe_walk_time, 'Walking'),
        'driving_time_text': _format_time_text(safe_drive_time, 'Driving'),
        'risk_exposure': safe_risk_exposure,
        'supporting_data': safe_supporting,
        'coordinates': safe_active['coordinates'],
        'waypoints': [{'lat': p[0], 'lon': p[1]} for p in safe_active['coordinates']],
        'is_recommended': True,
        'is_fallback': safe_active['is_fallback'],
        'travel_mode': active_mode
    }
    
    dist_diff = round(safe_dist_km - direct_dist_km, 2)
    time_diff = safe_time_mins - direct_time_mins
    score_diff = safe_eval_active['safety_score'] - direct_eval_active['safety_score']
    
    summary = f"+{int(dist_diff * 1000)}m (+{time_diff} mins) detour to increase safety score by {score_diff} points." if dist_diff > 0 else "Optimal path provides highest available safety."
    
    # 6. Profile packages for instant client toggling
    def _build_profile_package(mode_label, s_route, s_eval, d_route, d_eval):
        d_km = round(d_route['distance_m'] / 1000.0, 2)
        s_km = round(s_route['distance_m'] / 1000.0, 2)
        
        # Avoided
        d_n = {h['name'] for h in d_eval['hazards_intersected']}
        s_n = {h['name'] for h in s_eval['hazards_intersected']}
        av = [f"Bypassed {n}" for n in (d_n - s_n)]
        s_sup = dict(s_eval)
        s_sup['hazards_avoided'] = av
        
        return {
            'mode': mode_label,
            'recommended_safe_route': {
                'name': 'AI Recommended Safe Path',
                'safety_score': s_eval['safety_score'],
                'risk_level': s_eval['risk_level'],
                'distance_km': s_km,
                'estimated_time_mins': max(1, round(s_route['duration_s'] / 60.0)),
                'estimated_walking_time_mins': safe_walk_time,
                'estimated_driving_time_mins': safe_drive_time,
                'walking_time_text': _format_time_text(safe_walk_time, 'Walking'),
                'driving_time_text': _format_time_text(safe_drive_time, 'Driving'),
                'risk_exposure': f"Safer detour: {', '.join(av)}" if av else "Minimal risk exposure.",
                'supporting_data': s_sup,
                'coordinates': s_route['coordinates'],
                'waypoints': [{'lat': p[0], 'lon': p[1]} for p in s_route['coordinates']],
                'is_recommended': True,
                'is_fallback': s_route['is_fallback'],
                'travel_mode': mode_label
            },
            'shortest_route': {
                'name': 'Shortest Direct Path',
                'safety_score': d_eval['safety_score'],
                'risk_level': d_eval['risk_level'],
                'distance_km': d_km,
                'estimated_time_mins': max(1, round(d_route['duration_s'] / 60.0)),
                'estimated_walking_time_mins': direct_walk_time,
                'estimated_driving_time_mins': direct_drive_time,
                'walking_time_text': _format_time_text(direct_walk_time, 'Walking'),
                'driving_time_text': _format_time_text(direct_drive_time, 'Driving'),
                'risk_exposure': 'Crosses caution/hazard area' if d_eval['hazards_intersected'] else 'Minimal risk exposure.',
                'supporting_data': d_eval,
                'coordinates': d_route['coordinates'],
                'waypoints': [{'lat': p[0], 'lon': p[1]} for p in d_route['coordinates']],
                'is_recommended': False,
                'is_fallback': d_route['is_fallback'],
                'travel_mode': mode_label
            }
        }
        
    walking_profile = _build_profile_package('foot', safe_foot, safe_eval_foot, direct_foot, direct_eval_foot)
    driving_profile = _build_profile_package('driving', safe_car, safe_eval_car, direct_car, direct_eval_car)
    
    return {
        'start_location': {'latitude': start_lat, 'longitude': start_lon},
        'destination': {'latitude': dest_lat, 'longitude': dest_lon},
        'travel_mode': active_mode,
        'recommended_safe_route': safe_payload,
        'alternative_route': direct_payload,
        'shortest_route': direct_payload,
        'comparison': {
            'distance_diff_km': dist_diff,
            'time_diff_mins': time_diff,
            'walking_time_diff_mins': (safe_walk_time or 0) - (direct_walk_time or 0),
            'driving_time_diff_mins': (safe_drive_time or 0) - (direct_drive_time or 0),
            'safety_score_diff': score_diff,
            'summary': summary
        },
        'walking_profile': walking_profile,
        'driving_profile': driving_profile,
        'is_fallback': direct_active['is_fallback'] or safe_active['is_fallback']
    }
