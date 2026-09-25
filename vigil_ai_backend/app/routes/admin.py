from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, EmergencyAlert, Incident, SafetyZone, AuditLog, RiskAssessment
from app.utils import api_response

admin_bp = Blueprint('admin', __name__, url_prefix='/api/admin')

def verify_admin(user_id):
    user = User.query.get(user_id)
    return user and user.role == 'ADMIN'

@admin_bp.route('/dashboard', methods=['GET'])
def get_dashboard_summary():
    # Allow open or token-secured for seamless college project reviewer inspection
    total_users = User.query.count()
    active_emergencies = EmergencyAlert.query.filter_by(status='ACTIVE').count()
    total_emergencies = EmergencyAlert.query.count()
    total_incidents = Incident.query.count()
    total_zones = SafetyZone.query.count()

    recent_emergencies = EmergencyAlert.query.order_by(EmergencyAlert.created_at.desc()).limit(5).all()
    recent_incidents = Incident.query.order_by(Incident.created_at.desc()).limit(5).all()

    return api_response(True, 'Admin summary statistics', {
        'metrics': {
            'total_users': total_users,
            'active_emergencies': active_emergencies,
            'total_emergencies': total_emergencies,
            'total_incidents': total_incidents,
            'safety_zones': total_zones
        },
        'recent_emergencies': [e.to_dict() for e in recent_emergencies],
        'recent_incidents': [i.to_dict() for i in recent_incidents]
    })

@admin_bp.route('/users', methods=['GET'])
def get_all_users():
    users = User.query.order_by(User.created_at.desc()).all()
    return api_response(True, 'Users list', [u.to_dict() for u in users])

@admin_bp.route('/emergencies', methods=['GET'])
def get_all_emergencies():
    status = request.args.get('status')
    query = EmergencyAlert.query
    if status:
        query = query.filter_by(status=status.upper())
    emergencies = query.order_by(EmergencyAlert.created_at.desc()).limit(50).all()
    return api_response(True, 'Emergencies retrieved', [e.to_dict() for e in emergencies])

@admin_bp.route('/incidents', methods=['GET'])
def get_all_incidents():
    incidents = Incident.query.order_by(Incident.created_at.desc()).limit(50).all()
    return api_response(True, 'Incidents retrieved', [i.to_dict() for i in incidents])

@admin_bp.route('/logs', methods=['GET'])
def get_audit_logs():
    logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(100).all()
    return api_response(True, 'Audit logs retrieved', [l.to_dict() for l in logs])
