from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, Profile
from app.utils import api_response

users_bp = Blueprint('users', __name__, url_prefix='/api/users')

@users_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)
    return api_response(True, 'Profile fetched', user.to_dict())

@users_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return api_response(False, 'User not found', status_code=404)

    data = request.get_json() or {}
    if 'full_name' in data:
        user.full_name = data['full_name'].strip()
    if 'phone' in data:
        user.phone = data['phone'].strip()

    if not user.profile:
        user.profile = Profile(user_id=user.id)

    if 'blood_group' in data:
        user.profile.blood_group = data['blood_group']
    if 'medical_notes' in data:
        user.profile.medical_notes = data['medical_notes']
    if 'avatar_url' in data:
        user.profile.avatar_url = data['avatar_url']

    db.session.commit()
    return api_response(True, 'Profile updated successfully', user.to_dict())

@users_bp.route('/settings', methods=['PUT'])
@jwt_required()
def update_settings():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user or not user.profile:
        return api_response(False, 'Profile not found', status_code=404)

    data = request.get_json() or {}
    profile = user.profile

    if 'emergency_countdown' in data:
        profile.emergency_countdown = int(data['emergency_countdown'])
    if 'shake_to_sos' in data:
        profile.shake_to_sos = bool(data['shake_to_sos'])
    if 'voice_distress_detection' in data:
        profile.voice_distress_detection = bool(data['voice_distress_detection'])
    if 'fall_detection' in data:
        profile.fall_detection = bool(data['fall_detection'])
    if 'demo_mode' in data:
        profile.demo_mode = bool(data['demo_mode'])

    db.session.commit()
    return api_response(True, 'Settings updated', profile.to_dict())
