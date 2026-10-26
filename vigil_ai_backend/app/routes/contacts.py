from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, TrustedContact
from app.services.sms_service import SMSService
from app.utils import api_response

contacts_bp = Blueprint('contacts', __name__, url_prefix='/api/contacts')

@contacts_bp.route('', methods=['GET'])
@jwt_required()
def get_contacts():
    user_id = int(get_jwt_identity())
    contacts = TrustedContact.query.filter_by(user_id=user_id).order_by(TrustedContact.priority.asc(), TrustedContact.id.asc()).all()
    return api_response(True, 'Contacts retrieved successfully', [c.to_dict() for c in contacts])


@contacts_bp.route('', methods=['POST'])
@jwt_required()
def add_contact():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    name = data.get('name', '').strip()
    raw_phone = data.get('phone', '').strip()
    email = data.get('email', '').strip()
    relationship = data.get('relationship', 'Friend')
    priority = int(data.get('priority', 1))
    preference = data.get('notification_preference', 'ALL')

    if not name:
        return api_response(False, 'Contact name is required', status_code=400)
    if not raw_phone:
        return api_response(False, 'Phone number is required', status_code=400)

    # Validate phone digit count
    digits_only = ''.join(c for c in raw_phone if c.isdigit())
    if len(digits_only) < 10:
        return api_response(False, 'Please enter a valid phone number with at least 10 digits', status_code=400)

    # Normalize phone to E.164 standard format (+91...)
    normalized_phone = SMSService.normalize_phone_number(raw_phone)

    # Check for existing contact with same normalized phone for this user
    existing = TrustedContact.query.filter_by(user_id=user_id, phone=normalized_phone).first()
    if existing:
        return api_response(False, f'A contact with phone {normalized_phone} already exists in your account', status_code=409)

    contact = TrustedContact(
        user_id=user_id,
        name=name,
        phone=normalized_phone,
        email=email if email else None,
        relationship=relationship,
        priority=priority,
        notification_preference=preference
    )
    db.session.add(contact)
    db.session.commit()

    return api_response(True, 'Emergency contact added successfully', contact.to_dict(), status_code=201)


@contacts_bp.route('/<int:contact_id>', methods=['PUT'])
@jwt_required()
def update_contact(contact_id):
    user_id = int(get_jwt_identity())
    contact = TrustedContact.query.filter_by(id=contact_id, user_id=user_id).first()
    if not contact:
        return api_response(False, 'Contact not found or does not belong to your account', status_code=404)

    data = request.get_json() or {}
    if 'name' in data:
        name = data['name'].strip()
        if not name:
            return api_response(False, 'Contact name cannot be empty', status_code=400)
        contact.name = name

    if 'phone' in data:
        raw_phone = data['phone'].strip()
        digits_only = ''.join(c for c in raw_phone if c.isdigit())
        if len(digits_only) < 10:
            return api_response(False, 'Please enter a valid phone number with at least 10 digits', status_code=400)
        normalized = SMSService.normalize_phone_number(raw_phone)

        # Check if another contact of this user already has this phone
        conflict = TrustedContact.query.filter(
            TrustedContact.user_id == user_id,
            TrustedContact.phone == normalized,
            TrustedContact.id != contact_id
        ).first()
        if conflict:
            return api_response(False, f'Another contact already uses {normalized}', status_code=409)

        contact.phone = normalized

    if 'email' in data:
        e = data['email'].strip()
        contact.email = e if e else None
    if 'relationship' in data:
        contact.relationship = data['relationship']
    if 'priority' in data:
        contact.priority = int(data['priority'])
    if 'is_active' in data:
        contact.is_active = bool(data['is_active'])
    if 'notification_preference' in data:
        contact.notification_preference = data['notification_preference']

    db.session.commit()
    return api_response(True, 'Emergency contact updated successfully', contact.to_dict())


@contacts_bp.route('/<int:contact_id>', methods=['DELETE'])
@jwt_required()
def delete_contact(contact_id):
    user_id = int(get_jwt_identity())
    contact = TrustedContact.query.filter_by(id=contact_id, user_id=user_id).first()
    if not contact:
        return api_response(False, 'Contact not found or does not belong to your account', status_code=404)

    db.session.delete(contact)
    db.session.commit()
    return api_response(True, f'Contact "{contact.name}" removed successfully')


@contacts_bp.route('/clean-demo', methods=['DELETE'])
@jwt_required()
def clean_demo_contacts():
    """
    Safely removes demo/placeholder contacts (e.g. from seed data like example.com or demo tags)
    specifically for the authenticated user, without touching custom added contacts.
    """
    user_id = int(get_jwt_identity())
    demo_contacts = TrustedContact.query.filter(
        TrustedContact.user_id == user_id,
        (
            TrustedContact.email.like('%@example.com%') |
            TrustedContact.name.like('%(Mother)%') |
            TrustedContact.name.like('%(Father)%') |
            TrustedContact.name.like('%(Best Friend)%') |
            TrustedContact.phone.in_(['+919876543220', '+919876543221', '+919876543222'])
        )
    ).all()

    count = len(demo_contacts)
    for c in demo_contacts:
        db.session.delete(c)
    db.session.commit()

    return api_response(True, f'Removed {count} demo contact(s) from your account', {'deleted_count': count})
