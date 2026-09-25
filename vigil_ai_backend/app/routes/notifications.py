from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, Notification
from app.utils import api_response

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')

@notifications_bp.route('', methods=['GET'])
@jwt_required()
def get_notifications():
    user_id = get_jwt_identity()
    limit = int(request.args.get('limit', 30))
    notifs = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc()).limit(limit).all()
    return api_response(True, 'Notifications retrieved', [n.to_dict() for n in notifs])

@notifications_bp.route('/read/<int:notification_id>', methods=['POST'])
@jwt_required()
def mark_read(notification_id):
    user_id = get_jwt_identity()
    notif = Notification.query.filter_by(id=notification_id, user_id=user_id).first()
    if not notif:
        return api_response(False, 'Notification not found', status_code=404)

    notif.is_read = True
    db.session.commit()
    return api_response(True, 'Notification marked as read', notif.to_dict())

@notifications_bp.route('/read-all', methods=['POST'])
@jwt_required()
def mark_all_read():
    user_id = get_jwt_identity()
    Notification.query.filter_by(user_id=user_id, is_read=False).update({'is_read': True})
    db.session.commit()
    return api_response(True, 'All notifications marked as read')
