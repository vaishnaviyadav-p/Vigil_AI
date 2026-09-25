from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, TrustedContact
from app.utils import api_response

contacts_bp = Blueprint('contacts', __name__, url_prefix='/api/contacts')

@contacts_bp.route('', methods=['GET'])
@jwt_required()
def get_contacts():
    user_id = get_jwt_identity()
    contacts = TrustedContact.query.filter_by(user_id=user_id).order_by(TrustedContact.priority.asc()).all()
    return api_response(True, 'Contacts retrieved', [c.to_dict() for c in contacts])

@contacts_bp.route('', methods=['POST'])
@jwt_required()
def add_contact():
    user_id = get_jwt_identity()
    data = request.get_json() or {}

    name = data.get('name', '').strip()
    phone = data.get('phone', '').strip()
    email = data.get('email', '').strip()
    relationship = data.get('relationship', 'Friend')
    priority = int(data.get('priority', 1))
    preference = data.get('notification_preference', 'ALL')

    if not name or not phone:
        return api_response(False, 'Name and phone are required', status_code=400)

    contact = TrustedContact(
        user_id=user_id,
        name=name,
        phone=phone,
        email=email,
        relationship=relationship,
        priority=priority,
        notification_preference=preference
    )
    db.session.add(contact)
    db.session.commit()

    return api_response(True, 'Contact added successfully', contact.to_dict(), status_code=201)

@contacts_bp.route('/<int:contact_id>', methods=['PUT'])
@jwt_required()
def update_contact(contact_id):
    user_id = get_jwt_identity()
    contact = TrustedContact.query.filter_by(id=contact_id, user_id=user_id).first()
    if not contact:
        return api_response(False, 'Contact not found', status_code=404)

    data = request.get_json() or {}
    if 'name' in data:
        contact.name = data['name'].strip()
    if 'phone' in data:
        contact.phone = data['phone'].strip()
    if 'email' in data:
        contact.email = data['email'].strip()
    if 'relationship' in data:
        contact.relationship = data['relationship']
    if 'priority' in data:
        contact.priority = int(data['priority'])
    if 'is_active' in data:
        contact.is_active = bool(data['is_active'])
    if 'notification_preference' in data:
        contact.notification_preference = data['notification_preference']

    db.session.commit()
    return api_response(True, 'Contact updated', contact.to_dict())

@contacts_bp.route('/<int:contact_id>', methods=['DELETE'])
@jwt_required()
def delete_contact(contact_id):
    user_id = get_jwt_identity()
    contact = TrustedContact.query.filter_by(id=contact_id, user_id=user_id).first()
    if not contact:
        return api_response(False, 'Contact not found', status_code=404)

    db.session.delete(contact)
    db.session.commit()
    return api_response(True, 'Contact removed successfully')
