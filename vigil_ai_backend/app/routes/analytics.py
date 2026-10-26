from flask import Blueprint, request
from app.models import db, Incident, EmergencyAlert, SafetyZone
from app.utils import api_response, haversine_distance
from app.services.route_service import calculate_safe_route_recommendation, geocode_search

analytics_bp = Blueprint('analytics', __name__, url_prefix='/api/analytics')

@analytics_bp.route('/heatmap', methods=['GET'])
def get_heatmap_points():
    points = []

    # Incident points weighted by severity
    severity_weights = {'LOW': 0.3, 'MEDIUM': 0.6, 'HIGH': 0.85, 'CRITICAL': 1.0}
    incidents = Incident.query.all()
    for inc in incidents:
        w = severity_weights.get(inc.severity, 0.5)
        points.append({
            'latitude': inc.latitude,
            'longitude': inc.longitude,
            'weight': w,
            'type': 'INCIDENT',
            'category': inc.category
        })

    # Emergency points
    emergencies = EmergencyAlert.query.all()
    for em in emergencies:
        points.append({
            'latitude': em.latitude,
            'longitude': em.longitude,
            'weight': 0.95,
            'type': 'EMERGENCY',
            'alert_type': em.alert_type
        })

    # Safety zones
    zones = SafetyZone.query.all()
    for z in zones:
        weight = 0.9 if z.zone_type == 'HIGH_RISK' else (0.5 if z.zone_type == 'CAUTION' else 0.1)
        points.append({
            'latitude': z.latitude,
            'longitude': z.longitude,
            'weight': weight,
            'type': 'ZONE',
            'zone_type': z.zone_type
        })

    return api_response(True, 'Heatmap data retrieved', {
        'total_points': len(points),
        'points': points
    })

@analytics_bp.route('/summary', methods=['GET'])
def get_analytics_summary():
    incidents_by_category = {}
    for inc in Incident.query.all():
        incidents_by_category[inc.category] = incidents_by_category.get(inc.category, 0) + 1

    emergencies_by_type = {}
    for em in EmergencyAlert.query.all():
        emergencies_by_type[em.alert_type] = emergencies_by_type.get(em.alert_type, 0) + 1

    return api_response(True, 'Analytics summary', {
        'incidents_by_category': incidents_by_category,
        'emergencies_by_type': emergencies_by_type
    })

@analytics_bp.route('/geocode', methods=['GET'])
def geocode_places():
    query = request.args.get('q', '').strip()
    if not query:
        return api_response(True, 'Empty query', [])
    
    # Check internal safety zones first
    results = []
    local_zones = SafetyZone.query.filter(SafetyZone.name.ilike(f"%{query}%")).all()
    for z in local_zones:
        results.append({
            'name': z.name,
            'display_name': f"{z.name} ({z.zone_type.replace('_', ' ').title()} Zone)",
            'latitude': z.latitude,
            'longitude': z.longitude,
            'is_internal': True
        })
        
    # Query Nominatim
    external = geocode_search(query)
    # Deduplicate
    for ext in external:
        if not any(abs(r['latitude'] - ext['latitude']) < 0.001 and abs(r['longitude'] - ext['longitude']) < 0.001 for r in results):
            results.append(ext)
            
    return api_response(True, 'Geocoding results', results[:10])

@analytics_bp.route('/routes', methods=['POST'])
def recommend_safe_route():
    """
    Computes a Recommended Safe Route vs Alternative Route.
    Evaluates exposure to safety zones and incident density using real GPS data.
    """
    data = request.get_json() or {}
    start_lat = data.get('start_lat')
    start_lon = data.get('start_lon')
    dest_lat = data.get('dest_lat')
    dest_lon = data.get('dest_lon')
    mode = data.get('mode', 'foot')

    if start_lat is None or start_lon is None or dest_lat is None or dest_lon is None:
        return api_response(False, 'start_lat, start_lon, dest_lat, and dest_lon are required', status_code=400)

    try:
        start_lat = float(start_lat)
        start_lon = float(start_lon)
        dest_lat = float(dest_lat)
        dest_lon = float(dest_lon)
    except (ValueError, TypeError):
        return api_response(False, 'Coordinates must be valid numbers', status_code=400)

    # Fetch active safety zones and recorded incidents from database
    zones = SafetyZone.query.filter_by(is_active=True).all()
    incidents = Incident.query.all()

    route_data = calculate_safe_route_recommendation(
        start_lat=start_lat,
        start_lon=start_lon,
        dest_lat=dest_lat,
        dest_lon=dest_lon,
        zones=zones,
        incidents=incidents,
        mode=mode
    )

    return api_response(True, 'Route recommendations evaluated', route_data)
