from datetime import datetime
from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import (
    db, User, EmergencyAlert, LocationHistory, Notification,
    RiskAssessment, AuditLog, TrustedContact
)
from app.ml.risk_model import RiskEngine
from app.utils import api_response

emergency_bp = Blueprint('emergency', __name__, url_prefix='/api/emergency')

@emergency_bp.route('/sos', methods=['POST'])
@jwt_required()
def trigger_sos():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)

    data = request.get_json() or {}
    lat = float(data.get('latitude', 12.9716))
    lon = float(data.get('longitude', 77.5946))
    accuracy = float(data.get('accuracy', 10.0))
    alert_type = data.get('alert_type', 'SOS_MANUAL')
    description = data.get('description', 'User triggered Emergency SOS via mobile app.')

    # Calculate real-time multi-factor risk score
    risk_eval = RiskEngine.evaluate(is_sos=True)
    calculated_risk = risk_eval['risk_score']

    # Create emergency alert
    emergency = EmergencyAlert(
        user_id=user.id,
        alert_type=alert_type,
        severity='CRITICAL',
        latitude=lat,
        longitude=lon,
        accuracy=accuracy,
        risk_score=calculated_risk,
        description=description,
        status='ACTIVE',
        is_live_sharing=True
    )
    db.session.add(emergency)
    db.session.flush()

    # Record location point
    loc_point = LocationHistory(
        user_id=user.id,
        emergency_id=emergency.id,
        latitude=lat,
        longitude=lon,
        accuracy=accuracy,
        is_emergency_point=True
    )
    db.session.add(loc_point)

    # Save risk assessment snapshot
    risk_record = RiskAssessment(
        user_id=user.id,
        risk_score=calculated_risk,
        risk_level=risk_eval['risk_level'],
        factors_json=risk_eval['factors'],
        latitude=lat,
        longitude=lon
    )
    db.session.add(risk_record)

    # Dispatch alerts to trusted contacts (in-app notifications & simulated dispatch)
    contacts = TrustedContact.query.filter_by(user_id=user.id, is_active=True).all()
    for contact in contacts:
        notif = Notification(
            user_id=user.id,
            title=f"EMERGENCY ALERT: {user.full_name}",
            body=f"SOS triggered near ({lat:.4f}, {lon:.4f}). Contact: {contact.name}",
            notification_type='SOS',
            data_payload={'emergency_id': emergency.id, 'lat': lat, 'lon': lon}
        )
        db.session.add(notif)

    # Audit log
    audit = AuditLog(
        user_id=user.id,
        action='SOS_TRIGGERED',
        endpoint='/api/emergency/sos',
        ip_address=request.remote_addr,
        details=f"SOS Alert #{emergency.id} initiated with risk score {calculated_risk}."
    )
    db.session.add(audit)
    db.session.commit()

    return api_response(True, 'Emergency SOS initiated successfully', {
        'emergency': emergency.to_dict(),
        'risk_evaluation': risk_eval,
        'contacts_notified': len(contacts)
    }, status_code=201)


@emergency_bp.route('/fall', methods=['POST'])
@jwt_required()
def trigger_fall_event():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)

    data = request.get_json() or {}
    lat = float(data.get('latitude', 12.9716))
    lon = float(data.get('longitude', 77.5946))
    magnitude = float(data.get('magnitude', 32.0))

    risk_eval = RiskEngine.evaluate(is_fall=True)

    emergency = EmergencyAlert(
        user_id=user.id,
        alert_type='FALL_DETECTED',
        severity='HIGH',
        latitude=lat,
        longitude=lon,
        risk_score=risk_eval['risk_score'],
        description=f"Automatic fall detected with peak acceleration {magnitude:.1f} m/s^2.",
        status='ACTIVE',
        is_live_sharing=True
    )
    db.session.add(emergency)
    db.session.flush()

    loc_point = LocationHistory(
        user_id=user.id,
        emergency_id=emergency.id,
        latitude=lat,
        longitude=lon,
        is_emergency_point=True
    )
    db.session.add(loc_point)

    notif = Notification(
        user_id=user.id,
        title="Fall Detected",
        body=f"Possible fall impact detected at your current coordinates.",
        notification_type='FALL',
        data_payload={'emergency_id': emergency.id}
    )
    db.session.add(notif)
    db.session.commit()

    return api_response(True, 'Fall emergency logged', {
        'emergency': emergency.to_dict(),
        'risk_evaluation': risk_eval
    }, status_code=201)


@emergency_bp.route('/voice', methods=['POST'])
@jwt_required()
def trigger_voice_distress():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)

    data = request.get_json() or {}
    keyword = data.get('keyword', 'HELP').upper()
    lat = float(data.get('latitude', 12.9716))
    lon = float(data.get('longitude', 77.5946))

    risk_eval = RiskEngine.evaluate(is_distress_voice=True, voice_keyword=keyword)

    emergency = EmergencyAlert(
        user_id=user.id,
        alert_type='VOICE_DISTRESS',
        severity='HIGH',
        latitude=lat,
        longitude=lon,
        risk_score=risk_eval['risk_score'],
        description=f"Voice distress keyword recognized: '{keyword}'.",
        status='ACTIVE',
        is_live_sharing=True
    )
    db.session.add(emergency)
    db.session.flush()

    db.session.commit()
    return api_response(True, 'Voice distress emergency logged', {
        'emergency': emergency.to_dict(),
        'risk_evaluation': risk_eval
    }, status_code=201)


@emergency_bp.route('/active', methods=['GET'])
@jwt_required()
def get_active_emergency():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)

    # Check for own active emergency
    active = EmergencyAlert.query.filter_by(
        user_id=user.id, status='ACTIVE'
    ).order_by(EmergencyAlert.created_at.desc()).first()

    # If none, check if trusted contact has an active emergency
    shared_active = []
    contact_records = TrustedContact.query.filter_by(phone=user.phone).all()
    for cr in contact_records:
        shared = EmergencyAlert.query.filter_by(
            user_id=cr.user_id, status='ACTIVE'
        ).first()
        if shared:
            shared_active.append(shared.to_dict())

    return api_response(True, 'Active emergency status', {
        'has_active': active is not None,
        'emergency': active.to_dict() if active else None,
        'shared_emergencies': shared_active
    })


@emergency_bp.route('/<int:emergency_id>/acknowledge', methods=['POST'])
@jwt_required()
def acknowledge_emergency(emergency_id):
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    emergency = db.session.get(EmergencyAlert, emergency_id)
    if not emergency:
        return api_response(False, 'Emergency not found', status_code=404)

    emergency.status = 'ACKNOWLEDGED'
    emergency.acknowledged_by = user.full_name if user else f"User #{user_id}"
    db.session.commit()
    return api_response(True, 'Emergency acknowledged', emergency.to_dict())


@emergency_bp.route('/<int:emergency_id>/resolve', methods=['POST'])
@jwt_required()
def resolve_emergency(emergency_id):
    emergency = db.session.get(EmergencyAlert, emergency_id)
    if not emergency:
        return api_response(False, 'Emergency not found', status_code=404)

    emergency.status = 'RESOLVED'
    emergency.is_live_sharing = False
    emergency.resolved_at = datetime.utcnow()
    db.session.commit()
    return api_response(True, 'Emergency marked as resolved', emergency.to_dict())


@emergency_bp.route('/<int:emergency_id>/cancel', methods=['POST'])
@jwt_required()
def cancel_emergency(emergency_id):
    emergency = db.session.get(EmergencyAlert, emergency_id)
    if not emergency:
        return api_response(False, 'Emergency not found', status_code=404)

    emergency.status = 'CANCELLED'
    emergency.is_live_sharing = False
    emergency.resolved_at = datetime.utcnow()
    db.session.commit()
    return api_response(True, 'Emergency cancelled by user', emergency.to_dict())


@emergency_bp.route('/history', methods=['GET'])
@jwt_required()
def get_emergency_history():
    user_id = get_jwt_identity()
    history = EmergencyAlert.query.filter_by(user_id=user_id).order_by(EmergencyAlert.created_at.desc()).all()
    return api_response(True, 'Emergency history retrieved', [e.to_dict() for e in history])
