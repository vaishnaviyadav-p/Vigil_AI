import os
from flask import Flask, render_template, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from app.config import Config
from app.models import db
from app.ml.predict import MLService

jwt = JWTManager()

def create_app(config_class=Config):
    app = Flask(__name__, template_folder='templates', static_folder='static')
    app.config.from_object(config_class)

    # Ensure uploads & model directories exist
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['ML_MODEL_DIR'], exist_ok=True)

    # Initialize extensions
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    db.init_app(app)
    jwt.init_app(app)

    # Register blueprints
    from app.routes.auth import auth_bp
    from app.routes.users import users_bp
    from app.routes.contacts import contacts_bp
    from app.routes.emergency import emergency_bp
    from app.routes.location import location_bp
    from app.routes.incidents import incidents_bp
    from app.routes.zones import zones_bp
    from app.routes.geofence import geofence_bp
    from app.routes.risk import risk_bp
    from app.routes.sensors import sensors_bp
    from app.routes.notifications import notifications_bp
    from app.routes.admin import admin_bp
    from app.routes.analytics import analytics_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(users_bp)
    app.register_blueprint(contacts_bp)
    app.register_blueprint(emergency_bp)
    app.register_blueprint(location_bp)
    app.register_blueprint(incidents_bp)
    app.register_blueprint(zones_bp)
    app.register_blueprint(geofence_bp)
    app.register_blueprint(risk_bp)
    app.register_blueprint(sensors_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(analytics_bp)

    # Root route and Admin Web Dashboard
    @app.route('/')
    def index():
        return {
            'system': 'VIGIL AI – AI/ML Based Women Safety Monitoring System',
            'status': 'OPERATIONAL',
            'version': '2.0.0',
            'api_base': '/api',
            'admin_dashboard': '/admin'
        }

    @app.route('/admin')
    def admin_dashboard():
        return render_template('admin_dashboard.html')

    @app.route('/track/<token>')
    def live_tracking_page(token):
        from app.models import EmergencyAlert
        emergency = EmergencyAlert.query.filter_by(tracking_token=token).first()
        if not emergency:
            return render_template('sos_tracking.html', error="Invalid or expired emergency tracking link.", emergency=None, token=token), 404
        return render_template('sos_tracking.html', error=None, emergency=emergency, token=token)

    @app.route('/uploads/<filename>')
    def uploaded_file(filename):
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

    # Initialize database tables and verify schema
    with app.app_context():
        try:
            db.create_all()
            with db.engine.connect() as conn:
                res = conn.execute(db.text("PRAGMA table_info(emergency_alerts);")).fetchall()
                cols = [row[1] for row in res]
                if 'tracking_token' not in cols:
                    conn.execute(db.text("ALTER TABLE emergency_alerts ADD COLUMN tracking_token VARCHAR(64);"))
                    conn.commit()
                    print("[VIGIL AI] Added column tracking_token to emergency_alerts table.")
                if 'last_location_update' not in cols:
                    conn.execute(db.text("ALTER TABLE emergency_alerts ADD COLUMN last_location_update DATETIME;"))
                    conn.commit()
                    print("[VIGIL AI] Added column last_location_update to emergency_alerts table.")
            print("[VIGIL AI] Database tables verified/created successfully.")
        except Exception as e:
            print(f"[VIGIL AI] Database schema check note: {e}")

        # Preload ML Service
        MLService.get_instance()

    return app
