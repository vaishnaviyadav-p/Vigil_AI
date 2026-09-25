from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, SensorReading
from app.ml.predict import MLService
from app.utils import api_response

sensors_bp = Blueprint('sensors', __name__, url_prefix='/api/sensors')

@sensors_bp.route('/stream', methods=['POST'])
@jwt_required()
def stream_sensor_data():
    user_id = get_jwt_identity()
    data = request.get_json() or {}

    samples = data.get('samples', [])
    single_x = data.get('x')
    single_y = data.get('y')
    single_z = data.get('z')

    if not samples and (single_x is not None and single_y is not None and single_z is not None):
        samples = [{'x': float(single_x), 'y': float(single_y), 'z': float(single_z)}]

    if not samples:
        return api_response(False, 'Sensor samples required', status_code=400)

    ml_service = MLService.get_instance()
    analysis = ml_service.predict_anomaly(samples)

    latest = samples[-1]
    lx = float(latest.get('x', 0.0))
    ly = float(latest.get('y', 0.0))
    lz = float(latest.get('z', 9.8))

    reading = SensorReading(
        user_id=user_id,
        accel_x=lx,
        accel_y=ly,
        accel_z=lz,
        magnitude=analysis['features']['mean_magnitude'],
        jerk=analysis['features']['jerk'],
        is_anomaly=analysis['is_anomaly'],
        activity_state=analysis['activity_state']
    )
    db.session.add(reading)
    db.session.commit()

    return api_response(True, 'Sensor data analyzed with ML Isolation Forest', {
        'analysis': analysis,
        'reading_id': reading.id
    })
