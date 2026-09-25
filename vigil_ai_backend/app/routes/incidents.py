from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, Incident, Notification
from app.utils import api_response

incidents_bp = Blueprint('incidents', __name__, url_prefix='/api/incidents')

@incidents_bp.route('', methods=['POST'])
@jwt_required()
def report_incident():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return api_response(False, 'User not found', status_code=404)

    data = request.get_json() or {}
    category = data.get('category', 'Other')
    description = data.get('description', '').strip()
    lat = data.get('latitude')
    lon = data.get('longitude')
    address = data.get('address', '')
    severity = data.get('severity', 'MEDIUM')
    image_url = data.get('image_url')

    if not description or lat is None or lon is None:
        return api_response(False, 'Description, latitude, and longitude are required', status_code=400)

    incident = Incident(
        user_id=user.id,
        category=category,
        description=description,
        latitude=float(lat),
        longitude=float(lon),
        address=address,
        severity=severity,
        image_url=image_url,
        status='REPORTED'
    )
    db.session.add(incident)

    notif = Notification(
        user_id=user.id,
        title="Incident Reported",
        body=f"Your report regarding '{category}' has been submitted for review.",
        notification_type='SYSTEM',
        data_payload={'incident_id': incident.id}
    )
    db.session.add(notif)
    db.session.commit()

    return api_response(True, 'Incident reported successfully', incident.to_dict(), status_code=201)

@incidents_bp.route('', methods=['GET'])
@jwt_required()
def get_all_incidents():
    incidents = Incident.query.order_by(Incident.created_at.desc()).limit(100).all()
    return api_response(True, 'Incidents retrieved', [inc.to_dict() for inc in incidents])

@incidents_bp.route('/user', methods=['GET'])
@jwt_required()
def get_user_incidents():
    user_id = get_jwt_identity()
    user_incidents = Incident.query.filter_by(user_id=user_id).order_by(Incident.created_at.desc()).all()
    return api_response(True, 'User incidents retrieved', [inc.to_dict() for inc in user_incidents])
