from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, Geofence, Notification
from app.utils import api_response, haversine_distance

geofence_bp = Blueprint('geofence', __name__, url_prefix='/api/geofence')

@geofence_bp.route('', methods=['GET'])
@jwt_required()
def get_geofence():
    user_id = get_jwt_identity()
    geofence = Geofence.query.filter_by(user_id=user_id, is_active=True).first()
    return api_response(True, 'Geofence retrieved', geofence.to_dict() if geofence else None)

@geofence_bp.route('', methods=['POST'])
@jwt_required()
def set_geofence():
    user_id = get_jwt_identity()
    data = request.get_json() or {}

    lat = data.get('latitude')
    lon = data.get('longitude')
    name = data.get('name', 'Personal Safe Zone')
    radius = float(data.get('radius_meters', 250.0))
    notify = bool(data.get('notify_on_exit', True))

    if lat is None or lon is None:
        return api_response(False, 'Latitude and longitude required', status_code=400)

    # Deactivate previous geofences for clean single boundary
    Geofence.query.filter_by(user_id=user_id).update({'is_active': False})

    geofence = Geofence(
        user_id=user_id,
        name=name,
        latitude=float(lat),
        longitude=float(lon),
        radius_meters=radius,
        notify_on_exit=notify,
        is_active=True
    )
    db.session.add(geofence)
    db.session.commit()

    return api_response(True, 'Geofence created', geofence.to_dict(), status_code=201)

@geofence_bp.route('/<int:geofence_id>', methods=['PUT'])
@jwt_required()
def update_geofence(geofence_id):
    user_id = get_jwt_identity()
    geofence = Geofence.query.filter_by(id=geofence_id, user_id=user_id).first()
    if not geofence:
        return api_response(False, 'Geofence not found', status_code=404)

    data = request.get_json() or {}
    if 'name' in data:
        geofence.name = data['name']
    if 'latitude' in data:
        geofence.latitude = float(data['latitude'])
    if 'longitude' in data:
        geofence.longitude = float(data['longitude'])
    if 'radius_meters' in data:
        geofence.radius_meters = float(data['radius_meters'])
    if 'notify_on_exit' in data:
        geofence.notify_on_exit = bool(data['notify_on_exit'])
    if 'is_active' in data:
        geofence.is_active = bool(data['is_active'])

    db.session.commit()
    return api_response(True, 'Geofence updated', geofence.to_dict())

@geofence_bp.route('/<int:geofence_id>', methods=['DELETE'])
@jwt_required()
def delete_geofence(geofence_id):
    user_id = get_jwt_identity()
    geofence = Geofence.query.filter_by(id=geofence_id, user_id=user_id).first()
    if not geofence:
        return api_response(False, 'Geofence not found', status_code=404)

    db.session.delete(geofence)
    db.session.commit()
    return api_response(True, 'Geofence deleted')

@geofence_bp.route('/check', methods=['POST'])
@jwt_required()
def check_geofence():
    user_id = get_jwt_identity()
    data = request.get_json() or {}
    lat = data.get('latitude')
    lon = data.get('longitude')

    if lat is None or lon is None:
        return api_response(False, 'Latitude and longitude required', status_code=400)

    geofence = Geofence.query.filter_by(user_id=user_id, is_active=True).first()
    if not geofence:
        return api_response(True, 'No active geofence configured', {'is_breached': False})

    dist = haversine_distance(float(lat), float(lon), geofence.latitude, geofence.longitude)
    is_breached = dist > geofence.radius_meters

    if is_breached and geofence.notify_on_exit:
        notif = Notification(
            user_id=user_id,
            title="Geofence Boundary Exited",
            body=f"You have stepped {dist - geofence.radius_meters:.0f}m outside your safe perimeter '{geofence.name}'.",
            notification_type='GEOFENCE',
            data_payload={'distance_meters': round(dist, 1)}
        )
        db.session.add(notif)
        db.session.commit()

    return api_response(True, 'Geofence checked', {
        'is_breached': is_breached,
        'distance_to_center_meters': round(dist, 1),
        'radius_meters': geofence.radius_meters,
        'geofence_name': geofence.name
    })
