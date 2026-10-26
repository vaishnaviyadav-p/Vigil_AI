from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(20), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default='USER', nullable=False)  # USER, TRUSTED_CONTACT, ADMIN
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    profile = db.relationship('Profile', backref='user', uselist=False, cascade='all, delete-orphan')
    contacts = db.relationship('TrustedContact', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    emergencies = db.relationship('EmergencyAlert', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    locations = db.relationship('LocationHistory', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    incidents = db.relationship('Incident', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    risk_assessments = db.relationship('RiskAssessment', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    sensor_readings = db.relationship('SensorReading', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    geofences = db.relationship('Geofence', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    notifications = db.relationship('Notification', backref='user', lazy='dynamic', cascade='all, delete-orphan')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            'id': self.id,
            'full_name': self.full_name,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'profile': self.profile.to_dict() if self.profile else None
        }


class Profile(db.Model):
    __tablename__ = 'profiles'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True)
    avatar_url = db.Column(db.String(255), nullable=True)
    blood_group = db.Column(db.String(10), nullable=True)
    medical_notes = db.Column(db.Text, nullable=True)
    emergency_countdown = db.Column(db.Integer, default=5)  # seconds
    shake_to_sos = db.Column(db.Boolean, default=True)
    voice_distress_detection = db.Column(db.Boolean, default=True)
    fall_detection = db.Column(db.Boolean, default=True)
    demo_mode = db.Column(db.Boolean, default=False)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'avatar_url': self.avatar_url,
            'blood_group': self.blood_group,
            'medical_notes': self.medical_notes,
            'emergency_countdown': self.emergency_countdown,
            'shake_to_sos': self.shake_to_sos,
            'voice_distress_detection': self.voice_distress_detection,
            'fall_detection': self.fall_detection,
            'demo_mode': self.demo_mode,
        }


class TrustedContact(db.Model):
    __tablename__ = 'trusted_contacts'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    name = db.Column(db.String(120), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    email = db.Column(db.String(120), nullable=True)
    relationship = db.Column(db.String(50), default='Friend')  # Parent, Sibling, Spouse, Friend, Colleague
    priority = db.Column(db.Integer, default=1)  # 1 = Primary, 2 = Secondary
    is_active = db.Column(db.Boolean, default=True)
    notification_preference = db.Column(db.String(20), default='ALL')  # ALL, SMS, PUSH, CALL
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'name': self.name,
            'phone': self.phone,
            'email': self.email,
            'relationship': self.relationship,
            'priority': self.priority,
            'is_active': self.is_active,
            'notification_preference': self.notification_preference,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class EmergencyAlert(db.Model):
    __tablename__ = 'emergency_alerts'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    alert_type = db.Column(db.String(50), default='SOS_MANUAL')  # SOS_MANUAL, FALL_DETECTED, VOICE_DISTRESS, SHAKE, GEOFENCE_BREACH
    severity = db.Column(db.String(20), default='HIGH')  # LOW, MEDIUM, HIGH, CRITICAL
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    accuracy = db.Column(db.Float, default=10.0)
    risk_score = db.Column(db.Float, default=75.0)
    description = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(20), default='ACTIVE', index=True)  # ACTIVE, ACKNOWLEDGED, RESOLVED, CANCELLED
    is_live_sharing = db.Column(db.Boolean, default=True)
    tracking_token = db.Column(db.String(64), unique=True, index=True, nullable=True)
    last_location_update = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    resolved_at = db.Column(db.DateTime, nullable=True)
    acknowledged_by = db.Column(db.String(120), nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'user_name': self.user.full_name if self.user else None,
            'user_phone': self.user.phone if self.user else None,
            'alert_type': self.alert_type,
            'severity': self.severity,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'accuracy': self.accuracy,
            'risk_score': self.risk_score,
            'description': self.description,
            'status': self.status,
            'is_live_sharing': self.is_live_sharing,
            'tracking_token': self.tracking_token,
            'last_location_update': self.last_location_update.isoformat() if self.last_location_update else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'resolved_at': self.resolved_at.isoformat() if self.resolved_at else None,
            'acknowledged_by': self.acknowledged_by
        }

    def to_public_dict(self):
        recent_locations = LocationHistory.query.filter_by(emergency_id=self.id)\
            .order_by(LocationHistory.timestamp.desc()).limit(30).all()
        breadcrumbs = [{
            'latitude': loc.latitude,
            'longitude': loc.longitude,
            'accuracy': loc.accuracy,
            'timestamp': loc.timestamp.isoformat() if loc.timestamp else None
        } for loc in reversed(recent_locations)]

        return {
            'emergency_id': self.id,
            'user_name': self.user.full_name if self.user else 'Vigil AI User',
            'alert_type': self.alert_type,
            'severity': self.severity,
            'status': self.status,
            'is_live_sharing': self.is_live_sharing,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'accuracy': self.accuracy,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_location_update': self.last_location_update.isoformat() if self.last_location_update else (self.created_at.isoformat() if self.created_at else None),
            'resolved_at': self.resolved_at.isoformat() if self.resolved_at else None,
            'breadcrumbs': breadcrumbs
        }


class LocationHistory(db.Model):
    __tablename__ = 'location_history'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    emergency_id = db.Column(db.Integer, db.ForeignKey('emergency_alerts.id', ondelete='SET NULL'), nullable=True)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    accuracy = db.Column(db.Float, default=5.0)
    speed = db.Column(db.Float, default=0.0)
    heading = db.Column(db.Float, default=0.0)
    altitude = db.Column(db.Float, default=0.0)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    is_emergency_point = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'emergency_id': self.emergency_id,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'accuracy': self.accuracy,
            'speed': self.speed,
            'heading': self.heading,
            'altitude': self.altitude,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'is_emergency_point': self.is_emergency_point
        }


class Incident(db.Model):
    __tablename__ = 'incidents'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    category = db.Column(db.String(50), nullable=False)  # Harassment, Suspicious Activity, Physical Threat, Theft, Accident, Other
    description = db.Column(db.Text, nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    address = db.Column(db.String(255), nullable=True)
    severity = db.Column(db.String(20), default='MEDIUM')  # LOW, MEDIUM, HIGH, CRITICAL
    image_url = db.Column(db.String(255), nullable=True)
    status = db.Column(db.String(20), default='REPORTED')  # REPORTED, VERIFIED, INVESTIGATING, RESOLVED
    incident_time = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'user_name': self.user.full_name if self.user else 'Anonymous',
            'category': self.category,
            'description': self.description,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'address': self.address,
            'severity': self.severity,
            'image_url': self.image_url,
            'status': self.status,
            'incident_time': self.incident_time.isoformat() if self.incident_time else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class SafetyZone(db.Model):
    __tablename__ = 'safety_zones'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=True)
    zone_type = db.Column(db.String(20), default='HIGH_RISK')  # SAFE, CAUTION, HIGH_RISK
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    radius_meters = db.Column(db.Float, default=300.0)
    risk_weight = db.Column(db.Float, default=25.0)  # Contributing factor to risk score
    is_active = db.Column(db.Boolean, default=True)
    created_by_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'zone_type': self.zone_type,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'radius_meters': self.radius_meters,
            'risk_weight': self.risk_weight,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class Geofence(db.Model):
    __tablename__ = 'geofences'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    name = db.Column(db.String(120), default='Home Safe Zone')
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    radius_meters = db.Column(db.Float, default=200.0)
    notify_on_exit = db.Column(db.Boolean, default=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'name': self.name,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'radius_meters': self.radius_meters,
            'notify_on_exit': self.notify_on_exit,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class RiskAssessment(db.Model):
    __tablename__ = 'risk_assessments'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    risk_score = db.Column(db.Float, nullable=False)  # 0 to 100
    risk_level = db.Column(db.String(20), nullable=False)  # SAFE, LOW, MEDIUM, HIGH, CRITICAL
    anomaly_detected = db.Column(db.Boolean, default=False)
    factors_json = db.Column(db.JSON, nullable=True)  # Breakdown of contributing weights
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'risk_score': round(self.risk_score, 1),
            'risk_level': self.risk_level,
            'anomaly_detected': self.anomaly_detected,
            'factors': self.factors_json or [],
            'latitude': self.latitude,
            'longitude': self.longitude,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }


class SensorReading(db.Model):
    __tablename__ = 'sensor_readings'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    accel_x = db.Column(db.Float, default=0.0)
    accel_y = db.Column(db.Float, default=0.0)
    accel_z = db.Column(db.Float, default=9.8)
    magnitude = db.Column(db.Float, default=9.8)
    jerk = db.Column(db.Float, default=0.0)
    is_anomaly = db.Column(db.Boolean, default=False)
    activity_state = db.Column(db.String(50), default='STATIONARY')  # STATIONARY, WALKING, RUNNING, FALL_IMPACT, SHAKING
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'accel_x': self.accel_x,
            'accel_y': self.accel_y,
            'accel_z': self.accel_z,
            'magnitude': round(self.magnitude, 2),
            'jerk': round(self.jerk, 2),
            'is_anomaly': self.is_anomaly,
            'activity_state': self.activity_state,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }


class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    title = db.Column(db.String(150), nullable=False)
    body = db.Column(db.Text, nullable=False)
    notification_type = db.Column(db.String(50), default='SAFETY_ALERT')  # SOS, FALL, VOICE, GEOFENCE, ZONE, SYSTEM
    is_read = db.Column(db.Boolean, default=False)
    data_payload = db.Column(db.JSON, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'title': self.title,
            'body': self.body,
            'notification_type': self.notification_type,
            'is_read': self.is_read,
            'data_payload': self.data_payload,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class AuditLog(db.Model):
    __tablename__ = 'audit_logs'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, nullable=True)
    action = db.Column(db.String(100), nullable=False)
    endpoint = db.Column(db.String(255), nullable=True)
    ip_address = db.Column(db.String(50), nullable=True)
    details = db.Column(db.Text, nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'action': self.action,
            'endpoint': self.endpoint,
            'ip_address': self.ip_address,
            'details': self.details,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }
