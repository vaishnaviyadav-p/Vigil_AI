from flask import Blueprint, request
from flask_jwt_extended import (
    create_access_token, create_refresh_token, jwt_required, get_jwt_identity
)
from app.models import db, User, Profile, AuditLog
from app.utils import api_response

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json() or {}
    full_name = data.get('full_name', '').strip()
    email = data.get('email', '').strip().lower()
    phone = data.get('phone', '').strip()
    password = data.get('password', '')
    confirm_password = data.get('confirm_password', '')
    role = data.get('role', 'USER').upper()

    if not full_name or not email or not phone or not password:
        return api_response(False, 'All fields are required', status_code=400)

    if confirm_password and password != confirm_password:
        return api_response(False, 'Passwords do not match', status_code=400)

    if len(password) < 6:
        return api_response(False, 'Password must be at least 6 characters', status_code=400)

    if User.query.filter((User.email == email) | (User.phone == phone)).first():
        return api_response(False, 'User with this email or phone already exists', status_code=409)

    user = User(
        full_name=full_name,
        email=email,
        phone=phone,
        role=role if role in ('USER', 'TRUSTED_CONTACT', 'ADMIN') else 'USER'
    )
    user.set_password(password)
    db.session.add(user)
    db.session.flush()

    profile = Profile(user_id=user.id)
    db.session.add(profile)

    audit = AuditLog(
        user_id=user.id,
        action='REGISTER',
        endpoint='/api/auth/register',
        ip_address=request.remote_addr,
        details=f"User {user.email} registered."
    )
    db.session.add(audit)
    db.session.commit()

    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))

    return api_response(True, 'Registration successful', {
        'user': user.to_dict(),
        'access_token': access_token,
        'refresh_token': refresh_token
    }, status_code=201)


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    identifier = data.get('email', '').strip().lower()  # accepts email or phone
    password = data.get('password', '')

    if not identifier or not password:
        return api_response(False, 'Email/Phone and password are required', status_code=400)

    user = User.query.filter(
        (User.email == identifier) | (User.phone == identifier)
    ).first()

    if not user or not user.check_password(password):
        return api_response(False, 'Invalid credentials', status_code=401)

    if not user.is_active:
        return api_response(False, 'Account is deactivated', status_code=403)

    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))

    audit = AuditLog(
        user_id=user.id,
        action='LOGIN',
        endpoint='/api/auth/login',
        ip_address=request.remote_addr,
        details=f"User {user.email} logged in."
    )
    db.session.add(audit)
    db.session.commit()

    return api_response(True, 'Login successful', {
        'user': user.to_dict(),
        'access_token': access_token,
        'refresh_token': refresh_token
    })


@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    identity = get_jwt_identity()
    new_access_token = create_access_token(identity=identity)
    return api_response(True, 'Token refreshed', {
        'access_token': new_access_token
    })


@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    user_id = get_jwt_identity()
    audit = AuditLog(
        user_id=int(user_id) if user_id else None,
        action='LOGOUT',
        endpoint='/api/auth/logout',
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()
    return api_response(True, 'Logout successful')


@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json() or {}
    email = data.get('email', '').strip().lower()
    user = User.query.filter_by(email=email).first()
    # In production send reset email/OTP; for demo provide verification success
    return api_response(True, 'If this email is registered, password reset instructions have been dispatched.')
