from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, RiskAssessment, SafetyZone, Incident
from app.ml.risk_model import RiskEngine
from app.utils import api_response, haversine_distance

risk_bp = Blueprint('risk', __name__, url_prefix='/api/risk')

@risk_bp.route('/evaluate', methods=['POST'])
@jwt_required()
def evaluate_risk():
    user_id = get_jwt_identity()
    data = request.get_json() or {}

    lat = data.get('latitude')
    lon = data.get('longitude')
    is_sos = bool(data.get('is_sos', False))
    is_fall = bool(data.get('is_fall', False))
    is_anomaly = bool(data.get('is_anomaly', False))
    anomaly_score = float(data.get('anomaly_score', 0.0))
    is_distress_voice = bool(data.get('is_distress_voice', False))
    voice_keyword = data.get('voice_keyword')
    user_activity = data.get('user_activity', 'STATIONARY')

    # Detect safety zone proximity
    zone_type = None
    if lat is not None and lon is not None:
        zones = SafetyZone.query.filter_by(is_active=True).all()
        for z in zones:
            if haversine_distance(float(lat), float(lon), z.latitude, z.longitude) <= z.radius_meters:
                zone_type = z.zone_type
                break

    # Detect nearby incident count (within 1 km)
    nearby_incidents_count = 0
    if lat is not None and lon is not None:
        incidents = Incident.query.all()
        for inc in incidents:
            if haversine_distance(float(lat), float(lon), inc.latitude, inc.longitude) <= 1000.0:
                nearby_incidents_count += 1

    risk_result = RiskEngine.evaluate(
        is_sos=is_sos,
        is_fall=is_fall,
        is_anomaly=is_anomaly,
        anomaly_score=anomaly_score,
        is_distress_voice=is_distress_voice,
        voice_keyword=voice_keyword,
        zone_type=zone_type,
        nearby_incidents_count=nearby_incidents_count,
        user_activity=user_activity
    )

    # Persist risk assessment
    assessment = RiskAssessment(
        user_id=user_id,
        risk_score=risk_result['risk_score'],
        risk_level=risk_result['risk_level'],
        anomaly_detected=is_anomaly or is_fall,
        factors_json=risk_result['factors'],
        latitude=float(lat) if lat is not None else None,
        longitude=float(lon) if lon is not None else None
    )
    db.session.add(assessment)
    db.session.commit()

    return api_response(True, 'Risk score evaluated', risk_result)

@risk_bp.route('/history', methods=['GET'])
@jwt_required()
def get_risk_history():
    user_id = get_jwt_identity()
    limit = int(request.args.get('limit', 20))
    records = RiskAssessment.query.filter_by(user_id=user_id).order_by(RiskAssessment.timestamp.desc()).limit(limit).all()
    return api_response(True, 'Risk history retrieved', [r.to_dict() for r in records])
