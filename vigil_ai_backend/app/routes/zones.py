from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, SafetyZone, Notification, User
from app.utils import api_response, haversine_distance

zones_bp = Blueprint('zones', __name__, url_prefix='/api/zones')

@zones_bp.route('', methods=['GET'])
@jwt_required()
def get_zones():
    zones = SafetyZone.query.filter_by(is_active=True).all()
    return api_response(True, 'Safety zones retrieved', [z.to_dict() for z in zones])

@zones_bp.route('/check', methods=['POST'])
@jwt_required()
def check_location_zone():
    data = request.get_json() or {}
    lat = data.get('latitude')
    lon = data.get('longitude')
    if lat is None or lon is None:
        return api_response(False, 'Latitude and longitude required', status_code=400)

    lat = float(lat)
    lon = float(lon)
    zones = SafetyZone.query.filter_by(is_active=True).all()

    matched_zone = None
    min_dist = float('inf')

    for z in zones:
        dist = haversine_distance(lat, lon, z.latitude, z.longitude)
        if dist <= z.radius_meters:
            matched_zone = z
            break
        elif dist < min_dist:
            min_dist = dist

    if matched_zone:
        return api_response(True, 'Zone match found', {
            'is_inside': True,
            'zone': matched_zone.to_dict(),
            'warning': f"Safety Alert: You have entered a configured {matched_zone.zone_type.replace('_', ' ').lower()} zone."
        })

    return api_response(True, 'Location clear of configured high-risk zones', {
        'is_inside': False,
        'zone': None,
        'distance_to_nearest_meters': round(min_dist, 1) if min_dist != float('inf') else None
    })

@zones_bp.route('', methods=['POST'])
@jwt_required()
def create_zone():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user or user.role != 'ADMIN':
        return api_response(False, 'Admin privileges required', status_code=403)

    data = request.get_json() or {}
    name = data.get('name', '').strip()
    zone_type = data.get('zone_type', 'HIGH_RISK').upper()
    lat = data.get('latitude')
    lon = data.get('longitude')
    radius = float(data.get('radius_meters', 300.0))
    desc = data.get('description', '')

    if not name or lat is None or lon is None:
        return api_response(False, 'Name, latitude, and longitude required', status_code=400)

    zone = SafetyZone(
        name=name,
        zone_type=zone_type,
        latitude=float(lat),
        longitude=float(lon),
        radius_meters=radius,
        description=desc,
        created_by_id=user.id
    )
    db.session.add(zone)
    db.session.commit()

    return api_response(True, 'Safety zone created', zone.to_dict(), status_code=201)
