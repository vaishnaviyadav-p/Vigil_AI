from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, LocationHistory, EmergencyAlert
from app.utils import api_response

location_bp = Blueprint('location', __name__, url_prefix='/api/location')

@location_bp.route('/current', methods=['GET'])
@jwt_required()
def get_current_location():
    user_id = get_jwt_identity()
    latest = LocationHistory.query.filter_by(user_id=user_id).order_by(LocationHistory.timestamp.desc()).first()
    if not latest:
        # Default fallback coords (e.g. Bangalore / college city)
        return api_response(True, 'No GPS points logged yet, returning nominal position', {
            'latitude': 12.9716,
            'longitude': 77.5946,
            'accuracy': 10.0,
            'speed': 0.0,
            'timestamp': None
        })
    return api_response(True, 'Current location', latest.to_dict())

@location_bp.route('/update', methods=['POST'])
@jwt_required()
def update_location():
    user_id = get_jwt_identity()
    data = request.get_json() or {}

    lat = data.get('latitude')
    lon = data.get('longitude')
    if lat is None or lon is None:
        return api_response(False, 'Latitude and longitude are required', status_code=400)

    accuracy = float(data.get('accuracy', 5.0))
    speed = float(data.get('speed', 0.0))
    heading = float(data.get('heading', 0.0))
    altitude = float(data.get('altitude', 0.0))
    emergency_id = data.get('emergency_id')

    loc = LocationHistory(
        user_id=user_id,
        emergency_id=emergency_id,
        latitude=float(lat),
        longitude=float(lon),
        accuracy=accuracy,
        speed=speed,
        heading=heading,
        altitude=altitude,
        is_emergency_point=bool(emergency_id is not None)
    )
    db.session.add(loc)
    db.session.commit()

    return api_response(True, 'Location recorded', loc.to_dict())

@location_bp.route('/history', methods=['GET'])
@jwt_required()
def get_location_history():
    user_id = get_jwt_identity()
    limit = int(request.args.get('limit', 50))
    history = LocationHistory.query.filter_by(user_id=user_id).order_by(LocationHistory.timestamp.desc()).limit(limit).all()
    return api_response(True, 'Location history retrieved', [l.to_dict() for l in history])

@location_bp.route('/start-sharing', methods=['POST'])
@jwt_required()
def start_sharing():
    user_id = get_jwt_identity()
    # Mark any active emergency or sharing session
    active = EmergencyAlert.query.filter_by(user_id=user_id, status='ACTIVE').first()
    if active:
        active.is_live_sharing = True
        db.session.commit()
    return api_response(True, 'Live location sharing is ACTIVE', {'is_live_sharing': True})

@location_bp.route('/stop-sharing', methods=['POST'])
@jwt_required()
def stop_sharing():
    user_id = get_jwt_identity()
    active_alerts = EmergencyAlert.query.filter_by(user_id=user_id, is_live_sharing=True).all()
    for alert in active_alerts:
        alert.is_live_sharing = False
    db.session.commit()
    return api_response(True, 'Live location sharing has been STOPPED', {'is_live_sharing': False})
